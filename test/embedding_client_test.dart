import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:hitomi/src/client.dart';
import 'package:hitomi/src/user_config.dart';

/// 针对真实嵌入服务（llama.cpp 兼容的 `/v1/embeddings`）的集成测试。
///
/// 服务不可达、或未通过环境变量提供密钥时整个文件自动跳过，不影响离线 CI。
/// 本地跑法：
///
/// ```bash
/// HITOMI_EMB_KEY=sk-xxx dart test test/embedding_client_test.dart
/// ```
final serviceBase =
    Platform.environment['HITOMI_EMB_BASE'] ?? 'http://127.0.0.1:8080';
final serviceKey = Platform.environment['HITOMI_EMB_KEY'] ?? '';
final embeddingModel = Platform.environment['HITOMI_EMB_MODEL'] ?? 'embedding';

/// 该服务上 `embedding` 模型的向量维度（服务端已做 L2 归一化）。
final embeddingDim =
    int.parse(Platform.environment['HITOMI_EMB_DIM'] ?? '2048');

Future<bool> serviceReachable() async {
  if (serviceKey.isEmpty) return false;
  try {
    final r = await http
        .get(
          Uri.parse('$serviceBase/v1/models'),
          headers: {'Authorization': 'Bearer $serviceKey'},
        )
        .timeout(const Duration(seconds: 5));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// 生成纯色图形测试图（与手工验证脚本一致，结果可复现）
Uint8List makeTestPng(int Function(int x, int y) color) {
  final image = img.Image(width: 512, height: 512);
  for (var y = 0; y < 512; y++) {
    for (var x = 0; x < 512; x++) {
      final c = color(x, y);
      image.setPixelRgb(
        x,
        y,
        (c >> 16) & 0xFF,
        (c >> 8) & 0xFF,
        c & 0xFF,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

double cosine(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s; // 单位向量
}

void main() async {
  final reachable = await serviceReachable();
  final skip = reachable ? false : '嵌入服务 $serviceBase 不可达，跳过集成测试';
  late LlamaClient client;

  setUpAll(() {
    if (reachable) {
      client = LlamaClient(
        config: UserConfig(
          'galleries',
          llamaBaseUri: serviceBase,
          llamaApiKey: serviceKey,
          embeddingModel: embeddingModel,
        ),
      );
    }
  });

  group('统一 OpenAI 格式多模态嵌入', () {
    test('文本嵌入：$embeddingDim 维、单位长度', () async {
      final v = await client.textEmbeddings(['a dog catching a frisbee']);
      expect(v, hasLength(1));
      expect(v.first, hasLength(embeddingDim));
      expect(cosine(v.first, v.first), closeTo(1.0, 1e-4));
    }, skip: skip);

    test('图片嵌入：Uint8List 自动转 data URL', () async {
      final png = makeTestPng((x, y) {
        final inCircle =
            (x - 256) * (x - 256) + (y - 256) * (y - 256) < 160 * 160;
        return inCircle ? 0xDC2828 : 0x1E50C8; // 蓝底红圆
      });
      final v = await client.imageEmbeddings(png, resize: false);
      expect(v, hasLength(embeddingDim));
      expect(cosine(v, v), closeTo(1.0, 1e-4));
    }, skip: skip);

    test('文字与图片混合一个请求，跨模态语义正确', () async {
      final redCircle = makeTestPng((x, y) {
        final inCircle =
            (x - 256) * (x - 256) + (y - 256) * (y - 256) < 160 * 160;
        return inCircle ? 0xDC2828 : 0x1E50C8;
      });
      final skyGrass = makeTestPng((x, y) {
        if (y > 300) return 0x3CA03C; // 草地
        final inSun = (x - 415) * (x - 415) + (y - 95) * (y - 95) < 55 * 55;
        return inSun ? 0xFFDC28 : 0x87CEEB; // 蓝天黄日
      });
      final vectors = await client.embedItems([
        'a red circle on a blue background',
        'a green field under a blue sky with the sun',
        redCircle,
        skyGrass,
      ]);
      expect(vectors, hasLength(4));
      for (final v in vectors) {
        expect(v, hasLength(embeddingDim));
      }
      // 文本与匹配图片的相似度应高于与其他图片
      expect(
        cosine(vectors[0], vectors[2]),
        greaterThan(cosine(vectors[0], vectors[3])),
      );
      expect(
        cosine(vectors[1], vectors[3]),
        greaterThan(cosine(vectors[1], vectors[2])),
      );
    }, skip: skip);

    test('图片加配套文本合成一条内容，只产出一个向量', () async {
      final redCircle = makeTestPng((x, y) {
        final inCircle =
            (x - 256) * (x - 256) + (y - 256) * (y - 256) < 160 * 160;
        return inCircle ? 0xDC2828 : 0x1E50C8;
      });
      final vectors = await client.embedItems([
        [redCircle, 'a red circle on a blue background'],
      ]);
      expect(vectors, hasLength(1));
      expect(vectors.first, hasLength(embeddingDim));
    }, skip: skip);

    test('promptName 透传不改变请求可用性', () async {
      // prompt_name 是否真正影响向量取决于服务端与模型；
      // 这里只保证透传后请求仍然正常返回对应维度的向量。
      const text = 'a dog catching a frisbee on the beach';
      final q = await client.textEmbeddings([text], promptName: 'query');
      final d = await client.textEmbeddings([text], promptName: 'document');
      expect(q.first, hasLength(embeddingDim));
      expect(d.first, hasLength(embeddingDim));
    }, skip: skip);

    test('同一样本重复嵌入结果稳定', () async {
      final a = await client.textEmbeddings(['stability check']);
      final b = await client.textEmbeddings(['stability check']);
      expect(cosine(a.first, b.first), greaterThan(0.9999));
    }, skip: skip);

    test('空输入返回空列表，不发请求', () async {
      expect(await client.textEmbeddings([]), isEmpty);
      expect(await client.embedItems([]), isEmpty);
    }, skip: skip);
  }, skip: skip);
}
