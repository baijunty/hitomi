import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hitomi/lib.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class LlamaClient {
  final UserConfig config;
  late Logger? logger = null;

  /// 远程嵌入模型是否处于已加载状态（服务端启动时一般已加载）
  bool _modelLoaded = true;

  /// 最近一次使用嵌入模型的时间，用于空闲卸载判断
  DateTime _lastUsedAt = DateTime.now();

  /// 并发去重，多个请求共享同一次加载过程
  Future<void>? _loading;

  /// 进行中的卸载请求，避免与新的嵌入请求竞争
  Future<bool>? _unloading;

  LlamaClient({required this.config, this.logger = null});

  /// 最近一次嵌入请求时间
  DateTime get lastUsedAt => _lastUsedAt;

  /// 远程嵌入模型当前是否已加载
  bool get isModelLoaded => _modelLoaded;

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

  /// 确保远程嵌入模型已加载，被卸载后再次使用时自动重新加载
  Future<void> ensureLoaded() async {
    final pendingUnload = _unloading;
    if (pendingUnload != null) {
      // 等待进行中的卸载结束，避免加载与卸载交叉
      await pendingUnload;
    }
    if (_modelLoaded) {
      return;
    }
    await (_loading ??= loadModel().whenComplete(() {
      _loading = null;
    }));
  }

  /// 向模型管理接口发送 POST 请求，网络异常时返回 null
  Future<http.Response?> _postModelEndpoint(String endpoint, String model) async {
    final url = '${config.llamaBaseUri}$endpoint';
    try {
      logger?.d('$endpoint: 发送请求到 $url 模型 $model');
      return await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({'model': model}),
      );
    } catch (e) {
      logger?.e('$endpoint: 请求异常 $e');
      return null;
    }
  }

  /// 解析响应中的 success 字段，缺省时以 HTTP 状态码为准
  bool _isSuccess(http.Response? response) {
    if (response == null || response.statusCode != 200) {
      return false;
    }
    Object? body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      return true;
    }
    if (body is Map && body.containsKey('success')) {
      return body['success'] == true;
    }
    return true;
  }

  /// 加载远程嵌入模型 POST /models/load
  Future<bool> loadModel({String? model}) async {
    final name = model ?? config.embeddingModel;
    if (name.isEmpty) {
      return false;
    }
    final response = await _postModelEndpoint('/models/load', name);
    if (_isSuccess(response)) {
      _modelLoaded = true;
      logger?.i('loadModel: 模型 $name 加载完成');
      return true;
    }
    if (response != null &&
        (response.statusCode == 404 || response.statusCode == 405)) {
      // 服务端不支持按需加载接口时不再重复尝试
      _modelLoaded = true;
      logger?.w(
        'loadModel: 服务端不支持 /models/load, 状态码=${response.statusCode}',
      );
      return false;
    }
    logger?.e(
      'loadModel: 加载失败, 状态码=${response?.statusCode}, 响应=${response?.body}',
    );
    return false;
  }

  /// 卸载远程嵌入模型 POST /models/unload，释放服务端显存
  Future<bool> unloadModel({String? model}) {
    final pending = _unloading;
    if (pending != null) {
      return pending;
    }
    late Future<bool> future;
    future = _unload(model ?? config.embeddingModel).whenComplete(() {
      if (identical(_unloading, future)) {
        _unloading = null;
      }
    });
    _unloading = future;
    return future;
  }

  Future<bool> _unload(String name) async {
    if (name.isEmpty) {
      logger?.w('unloadModel: 未配置嵌入模型，跳过卸载');
      return false;
    }
    final response = await _postModelEndpoint('/models/unload', name);
    if (_isSuccess(response)) {
      _modelLoaded = false;
      logger?.i('unloadModel: 模型 $name 已卸载');
      return true;
    }
    logger?.e(
      'unloadModel: 卸载失败, 状态码=${response?.statusCode}, 响应=${response?.body}',
    );
    return false;
  }

  /// 多模态嵌入
  ///
  /// 根据传入的内容列表（文本和图片）返回对应的嵌入向量
  ///
  /// [contents] 内容列表，每个元素可以是:
  /// - {"prompt_string": "文本内容"}
  /// - {"prompt_string": "<__media__>", "image_data": [base64String, ...]}
  ///
  /// 返回结果按索引对应，每个元素为 Map<String, List<double>>
  Future<List<List<double>>> embedMultiModal(
    List<dynamic> contents, {
    bool openai = false,
  }) async {
    touch();
    await ensureLoaded();
    final request = <String, dynamic>{'model': config.embeddingModel};
    if (openai) {
      request['input'] = contents;
    } else {
      request['content'] = contents;
    }
    final url = openai
        ? '${config.llamaBaseUri}/v1/embeddings'
        : '${config.llamaBaseUri}/embeddings';
    logger?.i(
      'embedMultiModal: 发送请求到 $url 模型 ${config.embeddingModel} user openai $openai',
    );

    final response = await http.post(
      Uri.parse('$url'),
      headers: _headers,
      body: jsonEncode(request),
    );

    if (response.statusCode != 200) {
      logger?.e(
        'embedMultiModal: 请求失败, 状态码=${response.statusCode}, 响应=${response.body}',
      );
      return [];
    }

    if (openai) {
      // OpenAI 格式：响应为 {"data": [{"embedding": [...], "index": 0, "object": "embedding"}, ...]}
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final data = result['data'] as List<dynamic>;
      return data
          .map(
            (e) => List<double>.from((e as Map<String, dynamic>)['embedding']),
          )
          .toList();
    } else {
      // 原始格式：响应为 [{embedding: [[...]]}, ...]
      final result = jsonDecode(response.body) as List<dynamic>;

      return result
          .map(
            (e) =>
                List<double>.from((e as Map<String, dynamic>)['embedding'][0]!),
          )
          .toList();
    }
  }

  /// 获取指定模型的 media_marker
  Future<String> _getMediaMarker() async {
    final response = await http.get(
      Uri.parse('${config.llamaBaseUri}/props?model=${config.embeddingModel}'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      logger?.e(
        '_getMediaMarker: 请求失败, 状态码=${response.statusCode}, 响应=${response.body}',
      );
      return '<__media__>';
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final marker = result['media_marker'];
    logger?.d('_getMediaMarker: media_marker=$marker');
    return marker ?? '<__media__>';
  }

  /// 图片嵌入
  ///
  /// [imagePath] 图片路径
  /// 返回图片的嵌入向量
  Future<List<double>> imageEmbeddings(
    Uint8List dates, {
    bool resize = true,
  }) async {
    touch();
    await ensureLoaded();
    final bytes = resize ? await resizeThumbImage(dates, 640, 90) : dates;
    if (bytes == null) {
      return [];
    }
    logger?.d('imageEmbeddings: 开始处理图片嵌入, 图片大小=${bytes.length} 字节');
    final base64String = base64Encode(bytes);

    final mediaMarker = await _getMediaMarker();

    final result = await embedMultiModal([
      {
        'prompt_string': mediaMarker,
        'multimodal_data': [base64String],
      },
    ], openai: false);

    logger?.d('imageEmbeddings: 嵌入完成, 向量维度=${result[0].length}');
    return result[0];
  }

  /// 根据图片字节数据推断 MIME 类型
  String _detectImageMime(Uint8List bytes) {
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
