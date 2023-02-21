import 'dart:async';
import 'dart:isolate';
import 'package:collection/collection.dart';
import 'package:hitomi/src/hitomi.dart';
import 'package:hitomi/src/user_config.dart';
import 'package:tuple/tuple.dart';

import 'http_tools.dart';

class TaskManager {
  final List<Tuple2<StreamController<Message>, SendPort>> _pools = [];
  final UserConfig _config;
  final Set<_TaskImpl> _completes = {};
  List<Task> get tasks => _completes.toList();
  TaskManager(this._config);

  Future<Task> _pull(int id) async {
    var task = _TaskImpl(id, Completer());
    final t = _completes.firstWhereOrNull((element) => element == task);
    if (t == null) {
      _completes.add(task);
    } else {
      task = t;
    }
    if (_completes.length < _config.maxTasks) {
      final stream = await _initNewIsolate();
      task.completer.complete(stream);
    }
    return task;
  }

  Future<Tuple2<StreamController<Message>, SendPort>> _initNewIsolate() async {
    final recv = ReceivePort();
    final late = await Isolate.spawn(asyncDownload, recv.sendPort);
    final complete = Completer<Tuple2<StreamController<Message>, SendPort>>();
    final streamWarp = StreamController<Message>.broadcast();
    streamWarp.onCancel = () {
      late.kill();
      _pools.remove(streamWarp);
    };
    late Tuple2<StreamController<Message>, SendPort> tuple2;
    recv.forEach((message) {
      print('msg $message');
      if (message is SendPort) {
        tuple2 = Tuple2(streamWarp, message);
        message.send(_config);
      } else if (message is bool) {
        if (message) {
          complete.complete(tuple2);
        } else {
          complete.completeError('init async failed');
        }
      } else if (message is Message) {
        streamWarp.add(message);
        if (message.current == message.maxPage) {
          _completes.removeWhere((element) => element.id == message.id);
          final t = _completes.firstWhereOrNull((e) => !e.isRunning);
          if (t != null) {
            t.completer.complete(tuple2);
          }
        }
      }
    });
    return complete.future;
  }

  Future<Task> addNewTask(int id) async {
    final task = await _pull(id);
    task.start();
    return task;
  }
}

abstract class Task {
  int get id;
  bool get isRunning => status == TaskStatus.Running;
  TaskStatus get status;
  void start();
  void cancel();
}

class _TaskImpl extends Task {
  int id;
  late SendPort sender;
  Completer<Tuple2<StreamController<Message>, SendPort>> completer;
  Tuple2<StreamController<Message>, SendPort>? _tuple2;
  TaskStatus status = TaskStatus.UnStarted;
  _TaskImpl(this.id, this.completer);

  @override
  void start() async {
    _tuple2 = await completer.future;
    print('$_tuple2');
    status == TaskStatus.Running;
    _tuple2!.item1.stream.forEach((element) {
      print('$element');
    });
    _tuple2!.item2.send(id);
  }

  @override
  void cancel() {
    _tuple2?.item1.onCancel?.call();
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! _TaskImpl) return false;
    return other.id == id;
  }
}

enum TaskStatus {
  UnStarted,
  Running,
  Finished,
  Error;
}
