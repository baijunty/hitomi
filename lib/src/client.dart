import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:hitomi/lib.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class LlamaClient {
  final String baseUrl;
  final String apiKey;
  final String embeddingModel;
  final String imageModel;
  late Logger? logger = null;
  LlamaClient({
    required this.baseUrl,
    required this.apiKey,
    required this.embeddingModel,
    required this.imageModel,
    this.logger = null,
  });

  /// 构建请求头
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    };
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
  Future<List<List<double>>> embedMultiModal(List<dynamic> contents) async {
    logger?.i('embedMultiModal: 开始处理 ${contents.length} 个内容项');
    logger?.d('embedMultiModal: 请求模型=$embeddingModel');

    final request = {'model': embeddingModel, 'content': contents};

    logger?.d('embedMultiModal: 发送请求到 $baseUrl/embeddings');
    final stopwatch = Stopwatch()..start();

    final response = await http.post(
      Uri.parse('$baseUrl/embeddings'),
      headers: _headers,
      body: jsonEncode(request),
    );

    stopwatch.stop();
    logger?.d(
      'embedMultiModal: 响应耗时=${stopwatch.elapsedMilliseconds}ms, 状态码=${response.statusCode}',
    );

    if (response.statusCode != 200) {
      logger?.e(
        'embedMultiModal: 请求失败, 状态码=${response.statusCode}, 响应=${response.body}',
      );
      throw Exception(
        'Failed to get embeddings: ${response.statusCode} - ${response.body}',
      );
    }

    final result = jsonDecode(response.body) as List<dynamic>;
    logger?.i('embedMultiModal: 成功获取 ${result.length} 个嵌入向量');

    return result
        .map(
          (e) =>
              List<double>.from((e as Map<String, dynamic>)['embedding'][0]!),
        )
        .toList();
  }

  /// 图片嵌入
  ///
  /// [imagePath] 图片路径
  /// 返回图片的嵌入向量
  Future<List<double>> imageEmbeddings(
    Uint8List dates, {
    bool resize = true,
  }) async {
    final bytes = resize ? await resizeThumbImage(dates, 640, 90) : dates;
    if (bytes == null) {
      return [];
    }
    logger?.i('imageEmbeddings: 开始处理图片嵌入, 图片大小=${bytes.length} 字节');
    final base64String = base64Encode(bytes);
    logger?.d(
      'imageEmbeddings: base64编码后大小=${base64String.length} 字符${base64String.substring(0, 10)}',
    );

    final result = await embedMultiModal([
      {
        'prompt_string': '<__media__>',
        'multimodal_data': [base64String],
      },
    ]);

    logger?.i('imageEmbeddings: 嵌入完成, 向量维度=${result[0].length}');
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

    logger?.i('detectElements: 开始检测元素, 元素列表=${elements.join(", ")}');
    logger?.d('detectElements: 原始图片大小=${dates.length} 字节');

    final bytes = await resizeThumbImage(dates, 512);
    if (bytes == null) {
      logger?.w('detectElements: 图片缩略图生成失败，返回空结果');
      return {};
    }

    logger?.d(
      'detectElements: 缩略图大小=${bytes.length} 字节, MIME类型=${_detectImageMime(bytes)}',
    );

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
      'model': imageModel,
      'messages': messages,
      'tools': [tool],
      'tool_choice': 'auto',
      // 限制最大 token 数以控制响应大小
      'max_tokens': 1024,
    };

    logger?.d(
      'detectElements: 发送请求到 $baseUrl/chat/completions, 模型=$imageModel',
    );
    final stopwatch = Stopwatch()..start();

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: _headers,
      body: jsonEncode(request),
    );

    stopwatch.stop();
    logger?.d(
      'detectElements: 响应耗时=${stopwatch.elapsedMilliseconds}ms, 状态码=${response.statusCode}',
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

    logger?.d('detectElements: 模型调用了 ${toolCalls.length} 次工具函数');

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
