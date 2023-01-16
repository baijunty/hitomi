import 'dart:async';
import 'dart:isolate';
import 'package:dart_tools/hitomi.dart';

import 'http_tools.dart';

class TaskPools {
  final List<SendPort> _pools = [];
  final UserPrefenerce _config;
  final _port = ReceivePort();
  final StreamController<SendPort> _controller = StreamController.broadcast();
  late Hitomi api;
  TaskPools(this._config) {
    api = Hitomi.fromPrefenerce(_config);
    _port.listen((element) {
      if (element is SendPort) {
        _pools.add(element);
        element.send(api);
        _controller.add(element);
      }
    });
  }

  Future<SendPort> _poll() async {
    final SendPort port;
    if (_pools.isEmpty) {
      await Isolate.spawn(asyncDownload, _port.sendPort);
      port = await _controller.stream.first;
    } else {
      port = _pools[0];
    }
    _pools.remove(port);
    return port;
  }

  void sendNewTask(String id) async {
    final port = await _poll();
    print('send task $id');
    port.send(id);
  }
}
