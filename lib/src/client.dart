import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hitomi/lib.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class LlamaClient {
  final UserConfig config;
  late Logger? logger = null;

  /// 最近一次使用嵌入模型的时间，用于空闲卸载判断
  DateTime _lastUsedAt = DateTime.now();

  LlamaClient({required this.config, this.logger = null});

  /// 最近一次嵌入请求时间
  DateTime get lastUsedAt => _lastUsedAt;

  /// 记录一次嵌入模型使用时间
  void touch() {
    _lastUsedAt = DateTime.now();
  }

  /// 构建请求头
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (config.llamaApiKey.isNotEmpty)
        'Authorization': 'Bearer ${config.llamaApiKey}',
    };
  }

  /// 卸载远程嵌入模型 POST /models/unload，释放服务端显存
  ///
  /// 模型未加载时服务端会在下次请求时自动加载，客户端不维护加载状态
  Future<bool> unloadModel({String? model}) async {
    final name = model ?? config.embeddingModel;
    if (name.isEmpty) {
      logger?.w('unloadModel: 未配置嵌入模型，跳过卸载');
      return false;
    }
    final url = '${config.llamaBaseUri}/models/unload';
    try {
      logger?.d('unloadModel: 发送请求到 $url 模型 $name');
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({'model': name}),
      );
      if (response.statusCode == 200) {
        logger?.i('unloadModel: 模型 $name 已卸载');
        return true;
      }
      logger?.w(
        'unloadModel: 状态码=${response.statusCode}, 响应=${response.body}',
      );
      return false;
    } catch (e) {
      logger?.e('unloadModel: 请求异常 $e');
      return false;
    }
  }
  /// 文本 part，对应 `{"type": "text", "text": "..."}`
  static Map<String, dynamic> _textPart(String text) => {
    'type': 'text',
    'text': text,
  };

  /// 图片 part，字节数据统一编码成 `data:image/...;base64,` URL
  static Map<String, dynamic> _imagePart(Uint8List bytes) => {
    'type': 'image_url',
    'image_url': {
      'url': 'data:${_detectImageMime(bytes)};base64,${base64Encode(bytes)}',
    },
  };

  /// 把一条待嵌入内容映射成 `/v1/embeddings` 里的一个 `input` 元素。
  ///
  /// 接受 `String`（文本）、`Uint8List`（图片字节）或两者的 `Iterable`
  /// （同一内容里的多个部分，例如图片加配套文本）。
  static List<Map<String, dynamic>> _toParts(dynamic item) {
    if (item == null) return const [];
    if (item is String) return [_textPart(item)];
    if (item is Uint8List) return [_imagePart(item)];
    if (item is List<int>) return [_imagePart(Uint8List.fromList(item))];
    if (item is Map<String, dynamic>) return [item];
    if (item is Map) {
      return [item.cast<String, dynamic>()];
    }
    if (item is Iterable) {
      return item.expand(_toParts).toList();
    }
    return [_textPart(item.toString())];
  }

  /// 统一的多模态嵌入入口
  ///
  /// 文本与图片一律走 OpenAI 兼容的 `POST /v1/embeddings`，请求体形状见
  /// llama.cpp `tools/server/README.md` 的 "input as multimodal content"：
  ///
  /// ```json
  /// {
  ///   "model": "embedding",
  ///   "input": [
  ///     { "content": [
  ///         { "type": "image_url", "image_url": { "url": "data:image/png;base64,..." } },
  ///         { "type": "text", "text": "可选的配套文本" }
  ///     ] }
  ///   ]
  /// }
  /// ```
  ///
  /// [items] 每个元素表示一条待嵌入内容，可以是 `String`（文本）、
  /// `Uint8List`（图片字节，自动转 data URL）或一个 `Iterable`
  /// （把多个部分合成一条内容，只产出一个向量）。
  ///
  /// [promptName] 透传给服务端的 `prompt_name`（如 `query` / `document`），
  /// 是否生效取决于服务端与模型。
  ///
  /// 返回与 [items] 顺序一一对应的向量列表；[items] 为空时不发请求。
  /// 请求失败抛出 [Exception]。
  Future<List<List<double>>> embedItems(
    List<dynamic> items, {
    String? promptName,
  }) async {
    if (items.isEmpty) {
      return [];
    }
    touch();
    final request = <String, dynamic>{
      'model': config.embeddingModel,
      'input': items.map((item) => {'content': _toParts(item)}).toList(),
      'encoding_format': 'float',
      if (promptName != null && promptName.isNotEmpty) 'prompt_name': promptName,
    };
    final url = '${config.llamaBaseUri}/v1/embeddings';
    logger?.i(
      'embedItems: 发送请求到 $url 模型 ${config.embeddingModel} '
      '条数=${items.length}${promptName == null ? '' : ' prompt=$promptName'}',
    );

    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(request),
    );

    if (response.statusCode != 200) {
      logger?.e(
        'embedItems: 请求失败, 状态码=${response.statusCode}, 响应=${response.body}',
      );
      throw Exception(
        'embedItems failed: ${response.statusCode} - ${response.body}',
      );
    }

    final vectors = _parseOpenAiEmbeddings(response.body);
    logger?.d(
      'embedItems: 嵌入完成, 向量数=${vectors.length} 维度=${vectors.firstOrNull?.length ?? 0}',
    );
    return vectors;
  }

  /// 解析 OpenAI 嵌入响应 `{"data": [{"embedding": [...], "index": 0}, ...]}`
  ///
  /// 按 `index` 排序，保证与输入顺序严格对应。
  List<List<double>> _parseOpenAiEmbeddings(String body) {
    final result = jsonDecode(body);
    if (result is! Map<String, dynamic> || result['data'] is! List) {
      throw Exception('embedItems: 响应格式异常, 缺少 data 字段: $body');
    }
    final data = result['data'] as List;
    final indexed = <MapEntry<int, List<double>>>[];
    for (var i = 0; i < data.length; i++) {
      final item = data[i] as Map<String, dynamic>;
      indexed.add(
        MapEntry(
          (item['index'] as num?)?.toInt() ?? i,
          List<double>.from(item['embedding'] as List),
        ),
      );
    }
    indexed.sort((a, b) => a.key.compareTo(b.key));
    return indexed.map((e) => e.value).toList();
  }

  /// 文本嵌入
  ///
  /// [texts] 文本列表，返回顺序一致的向量列表。
  Future<List<List<double>>> textEmbeddings(
    List<String> texts, {
    String? promptName,
  }) => embedItems(texts, promptName: promptName);

  /// 图片嵌入
  ///
  /// [dates] 图片字节，[resize] 为真时先压缩成缩略图再嵌入。
  /// 返回图片的嵌入向量，失败或缩略图生成失败时返回空列表。
  Future<List<double>> imageEmbeddings(
    Uint8List dates, {
    bool resize = true,
  }) async {
    final bytes = resize ? await resizeThumbImage(dates, 640, 90) : dates;
    if (bytes == null) {
      logger?.w('imageEmbeddings: 缩略图生成失败，跳过嵌入');
      return [];
    }
    logger?.d('imageEmbeddings: 开始处理图片嵌入, 图片大小=${bytes.length} 字节');
    final result = await embedItems([bytes]);
    if (result.isEmpty) {
      logger?.w('imageEmbeddings: 未返回向量');
      return [];
    }
    logger?.d('imageEmbeddings: 嵌入完成, 向量维度=${result.first.length}');
    return result.first;
  }

  /// 根据图片字节数据推断 MIME 类型
  static String _detectImageMime(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'image/gif';
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'image/bmp';
    return 'image/jpeg';
  }

  /// 检测图片是否包含指定元素
  ///
  /// 使用视觉语言模型的 function calling 能力，在图片中检测指定的元素（如标签名）。
  /// 内部定义了一个 `report_elements` 函数，模型通过调用此函数来报告检测到的元素。
  ///
  /// [bytes] 图片字节数据
  /// [elements] 要检测的元素列表（如标签名）
  /// 返回 Map，键为元素名，值为是否包含该元素的布尔值
  Future<Map<String, bool>> detectElements(
    Uint8List dates,
    List<String> elements,
  ) async {
    if (elements.isEmpty) {
      logger?.w('detectElements: 元素列表为空，直接返回空结果');
      return {};
    }

    final bytes = await resizeThumbImage(dates, 640);
    if (bytes == null) {
      logger?.w('detectElements: 图片缩略图生成失败，返回空结果');
      return {};
    }

    final base64String = base64Encode(bytes);
    final mimeType = _detectImageMime(bytes);
    final dataUri = 'data:$mimeType;base64,$base64String';

    // 构建系统提示词
    const systemPrompt =
        'You are an image analysis assistant. Your task is to detect specific elements '
        'in images. Use the provided function to report which elements are present in '
        'the image. Be thorough and accurate - only report elements that you are '
        'confident are present.';

    // 定义工具函数，模型通过调用此函数来报告检测结果
    final tool = {
      'type': 'function',
      'function': {
        'name': 'report_elements',
        'description':
            'Report which of the specified elements are detected in the image',
        'parameters': {
          'type': 'object',
          'properties': {
            'detected': {
              'type': 'array',
              'items': {'type': 'string', 'enum': elements},
              'description': 'List of elements detected in the image',
            },
          },
          'required': ['detected'],
        },
      },
    };

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'user',
        'content': [
          {
            'type': 'text',
            'text':
                'Please analyze this image and detect if it contains any of the '
                'following elements: ${elements.join(', ')}. '
                'Use the report_elements function to report which elements you detect.',
          },
          {
            'type': 'image_url',
            'image_url': {'url': dataUri},
          },
        ],
      },
    ];

    final request = {
      'model': config.multimodal,
      'messages': messages,
      'tools': [tool],
      'tool_choice': 'auto',
      // 限制最大 token 数以控制响应大小
      'max_tokens': 1024,
    };

    logger?.d(
      'detectElements: 缩略图大小=${bytes.length} 字节, MIME类型=${mimeType} ${config.multimodal} ',
    );
    final response = await http.post(
      Uri.parse('${config.llamaBaseUri}/v1/chat/completions'),
      headers: _headers,
      body: jsonEncode(request),
    );

    if (response.statusCode != 200) {
      logger?.e(
        'detectElements: 请求失败, 状态码=${response.statusCode}, 响应=${response.body}',
      );
      throw Exception(
        'Failed to detect elements: ${response.statusCode} - ${response.body}',
      );
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    logger?.d('response reulst $result');
    final choices = result['choices'] as List<dynamic>;

    if (choices.isEmpty) {
      logger?.w('detectElements: 响应中无 choices，所有元素视为未检测到');
      return {for (final e in elements) e: false};
    }

    final message = choices[0]['message'] as Map<String, dynamic>;
    final toolCalls = message['tool_calls'] as List<dynamic>?;

    // 如果模型没有调用函数，则所有元素都视为未检测到
    if (toolCalls == null || toolCalls.isEmpty) {
      logger?.i('detectElements: 模型未调用 report_elements 函数，所有元素视为未检测到');
      return {for (final e in elements) e: false};
    }

    // 收集所有工具调用中报告的元素
    final detectedSet = <String>{};
    for (final toolCall in toolCalls) {
      final function = toolCall['function'] as Map<String, dynamic>;
      if (function['name'] != 'report_elements') continue;

      final args =
          jsonDecode(function['arguments'] as String) as Map<String, dynamic>;
      final detected = args['detected'] as List<dynamic>?;
      if (detected != null) {
        for (final e in detected) {
          detectedSet.add(e as String);
        }
      }
    }

    logger?.i('detectElements: 检测完成, 检测到的元素=[${detectedSet.join(", ")}]');

    // 构建结果 Map：用户指定的每个元素对应一个 bool
    return {for (final e in elements) e: detectedSet.contains(e)};
  }
}
