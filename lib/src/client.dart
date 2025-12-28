import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket/web_socket.dart';
import 'workflow_template.dart';

class ComfyClient {
  final String url;
  late String _clientId;
  final Dio _dio;
  final _queue = <String>[];
  WebSocket? _ws;
  ComfyClient(this.url, this._dio) {
    _clientId = Uuid().v4();
  }

  Future<void> _init() async {
    try {
      if (_ws == null) {
        var uri =
            '${url.startsWith('https') ? 'wss' : 'ws'}${url.substring(url.startsWith('https') ? 5 : 4)}/ws?clientId=$_clientId';
        _ws = await WebSocket.connect(Uri.parse(uri));
        loopForId();
      }
    } catch (e) {
      print(e);
      _ws?.close();
      _ws = null;
    }
  }

  Future<void> loopForId() async {
    await for (final out in _ws!.events) {
      if (out is TextDataReceived) {
        final message = json.decode(out.text);
        if (message is Map && message['type'] == 'executing') {
          final data = message['data'];
          if (data is Map &&
              data['node'] == null &&
              _queue.contains(data['prompt_id'])) {
            _queue.remove(data['prompt_id']);
          }
        }
      } else if (out is CloseReceived) {
        print('Connection closed ${out.reason}');
        _ws = null;
        break;
      }
    }
  }

  Future<void> close() async {
    await _ws?.close();
  }

  Future<Map<String, dynamic>> _queuePrompt(
    Map<String, dynamic> workflow,
  ) async {
    await _init();
    final response = await _dio.post<Map<String, dynamic>>(
      '$url/prompt',
      data: json.encode(workflow),
      options: Options(responseType: ResponseType.json),
    );
    print(response.data);
    return response.data!;
  }

  // ignore: unused_element
  Future<Uint8List> _getImage(
    String filename,
    String subfolder,
    String folderType,
  ) async {
    await _init();
    final data = {
      "filename": filename,
      "subfolder": subfolder,
      "type": folderType,
    };
    final urlValues = Uri(queryParameters: data).query;
    final response = await _dio.get<Uint8List>(
      '$url/view?$urlValues',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> _getHistory(String promptId) async {
    await _init();
    final response = await _dio.get<Map<String, dynamic>>(
      '$url/history/$promptId',
      options: Options(responseType: ResponseType.json),
    );
    return response.data!;
  }

  Future<List<Uint8List>> imageResize(String path, {int width = 384}) async {
    await _init();
    var workflow = resizeWorkflow as Map<String, dynamic>;
    workflow['client_id'] = this._clientId;
    workflow['prompt']['10']['inputs']['image_path_or_url'] = path;
    workflow['prompt']['50']['inputs']['shorter_edge'] = width;
    return await _queueTask<Map<String, dynamic>>(workflow, (nodeOutput) {
      return jsonDecode(nodeOutput);
    }).then((list) => list.map((e) => base64Decode(e.values.first)).toList());
  }

  Future<List<String>> imageTag(String path) async {
    await _init();
    var workflow = tagTriggerWorkflow as Map<String, dynamic>;
    workflow['client_id'] = this._clientId;
    workflow['prompt']['11']['inputs']['image_path_or_url'] = path;
    return await _queueTask<List<dynamic>>(workflow, (nodeOutput) {
      return jsonDecode(nodeOutput);
    }).then((list) => list.first.map((e) => e as String).toList());
  }

  Future<Map<String, List<double>>> imageEmbeddings(String path) async {
    await _init();
    var workflow = embeddingWorkflow as Map<String, dynamic>;
    workflow['client_id'] = this._clientId;
    workflow['prompt']['10']['inputs']['image_path_or_url'] = path;
    final outputImages =
        await _queueTask<Map<String, dynamic>>(workflow, (nodeOutput) {
          return jsonDecode(nodeOutput);
        }).then(
          (list) => list.fold(
            <String, List<double>>{},
            (acc, e) => acc
              ..[e.keys.first] = (e.values.first as List)
                  .map((ele) => ele as double)
                  .toList(),
          ),
        );
    return outputImages;
  }

  Future<Map<String, int>> imageHash(String path) async {
    await _init();
    var workflow = imageHashWorkflow as Map<String, dynamic>;
    workflow['client_id'] = this._clientId;
    workflow['prompt']['10']['inputs']['image_path_or_url'] = path;
    final outputImages =
        await _queueTask<Map<String, dynamic>>(workflow, (nodeOutput) {
          return jsonDecode(nodeOutput);
        }).then(
          (list) => list.fold(
            <String, int>{},
            (acc, e) => acc..[e.keys.first] = e.values.first as int,
          ),
        );
    return outputImages;
  }

  Future<List<T>> _queueTask<T>(
    Map<String, dynamic> workflow,
    FutureOr<T> Function(dynamic) process,
  ) async {
    await _init();
    final result = await _queuePrompt(workflow);
    final promptId = result['prompt_id'];
    final outputImages = <T>[];
    _queue.add(promptId);
    while (_queue.contains(promptId)) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    final history = await _getHistory(promptId);
    final promptHistory = history[promptId];
    if (promptHistory != null && promptHistory['outputs'] != null) {
      final outputs = promptHistory['outputs'];

      for (final nodeId in outputs.keys) {
        final results = outputs[nodeId];
        if (results is Map && results['text'] != null) {
          for (final nodeOutput in results['text']) {
            outputImages.add(await process(nodeOutput));
          }
        } else if (results is List) {
          for (final nodeOutput in results) {
            outputImages.add(await process(nodeOutput));
          }
        }
      }
    }
    return outputImages;
  }
}
