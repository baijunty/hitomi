import 'dart:async';
import 'dart:isolate';
import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';
import '../lib.dart';
import 'gallery_fix.dart';

class TaskManager {
  static final numbers = RegExp(r'^\d+$');
  final UserConfig _config;
  final Set<Task<Object>> _tasks = {};
  final List<Tuple2<StreamController<Message>, SendPort>> _tuples = [];
  List<Task<Object>> get tasks => _tasks.toList();
  TaskManager(this._config);

  Future<Task<Object>> _pull(String cmd) async {
    final t = _tasks.firstWhereOrNull((element) => element.id == cmd);
    late Task<Object> task;
    if (t == null) {
      task = (numbers.hasMatch(cmd)
          ? _GalleryTaskImpl(cmd.toInt(), Completer())
          : _CommandTaskImpl(cmd, Completer())) as Task<Object>;
      _tasks.add(task);
    } else {
      task = t;
    }
    if (_tuples.isNotEmpty) {
      print('$task complete with ${_tuples[0]}');
      task._completer.complete(_tuples.removeAt(0));
    } else if (_tasks.length + _tuples.length < _config.maxTasks) {
      print('$task with new isolate ');
      await _initNewIsolate();
    }
    return task;
  }

  Future<void> _initNewIsolate() async {
    final recv = ReceivePort();
    var late = await Isolate.spawn(asyncDownload, recv.sendPort);
    late SendPort sendPort;
    recv.forEach((message) {
      if (message is SendPort) {
        sendPort = message;
        message.send(_config);
      } else if (message is bool) {
        final streamWarp = StreamController<Message>();
        streamWarp.onCancel = () async {
          late.kill();
          late = await Isolate.spawn(asyncDownload, recv.sendPort);
        };
        _tryStartNext(Tuple2(streamWarp, sendPort));
      } else if (message is Message) {
        final t =
            _tasks.firstWhereOrNull((element) => element.id == message.id);
        t?._tuple2?.item1.add(message);
        if (message.runtimeType == Message) {
          if (!message.success) {
            t?.reset();
            _tasks.remove(t);
          } else {
            _tasks.removeWhere((element) => element.id == message.id);
            final streamWarp = StreamController<Message>();
            streamWarp.onCancel = () async {
              late.kill();
              late = await Isolate.spawn(asyncDownload, recv.sendPort);
            };
            _tryStartNext(Tuple2(streamWarp, sendPort));
          }
        }
      }
    });
  }

  void _tryStartNext(Tuple2<StreamController<Message>, SendPort> tuple2) {
    final t = _tasks
        .firstWhereOrNull((element) => element.status == TaskStatus.UnStarted);
    if (t != null) {
      t._completer.complete(tuple2);
    } else {
      _tuples.add(tuple2);
    }
  }

  Future<Task?> addNewTask(String cmd) async {
    return _pull(cmd.trim().trimRight());
  }
}

Future<void> asyncDownload(SendPort port) async {
  final receivePort = ReceivePort();
  port.send(receivePort.sendPort);
  late Hitomi api;
  var lastDate = DateTime.now();
  late GalleryFix fix;
  receivePort.listen((element) async {
    try {
      if (element is int) {
        int id = element;
        var b = await api.downloadImagesById(id, onProcess: (msg) {
          var now = DateTime.now();
          if (now.difference(lastDate).inMilliseconds > 300) {
            lastDate = now;
            port.send(msg);
          }
        });
        port.send(Message(id: id, success: b));
      } else if (element == ':fix') {
        bool b = await fix.fix();
        port.send(Message(id: element, success: b));
      } else if (element is UserConfig) {
        final prefenerce = UserContext(element);
        await prefenerce.initData();
        api = Hitomi.fromPrefenerce(prefenerce);
        fix = GalleryFix(prefenerce);
        port.send(true);
      }
    } catch (e) {
      print(e);
      port.send(Message(id: element, success: false));
    }
  });
}

abstract class Task<T> {
  T get id;
  bool get isRunning => status == TaskStatus.Running;
  late SendPort sender;
  Completer<Tuple2<StreamController<Message>, SendPort>> _completer;
  Tuple2<StreamController<Message>, SendPort>? _tuple2;
  TaskStatus status = TaskStatus.UnStarted;
  Task(this._completer);

  Future<void> start() async {
    if (!isRunning) {
      status = TaskStatus.UnStarted;
      _tuple2 ??= await _completer.future;
      status = TaskStatus.Running;
      _tuple2!.item2.send(id);
    }
  }

  void reset() {
    _completer = Completer();
    _tuple2 = null;
    status = TaskStatus.Finished;
  }

  void cancel() async {
    if (_tuple2 != null) {
      _tuple2?.item1.onCancel?.call();
      reset();
    }
  }

  void listen(void onData(Message msg),
      {void onDone()?, void onError(Exception e)?}) async {
    await start();
    _tuple2!.item1.stream.listen(onData, onDone: onDone, onError: onError);
  }
}

class _CommandTaskImpl extends Task<String> {
  String command;
  @override
  String get id => this.command;
  _CommandTaskImpl(this.command,
      Completer<Tuple2<StreamController<Message>, SendPort>> _completer)
      : super(_completer);
}

class _GalleryTaskImpl extends Task<int> {
  int galleyId;
  @override
  int get id => this.galleyId;
  _GalleryTaskImpl(this.galleyId,
      Completer<Tuple2<StreamController<Message>, SendPort>> _completer)
      : super(_completer);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! _GalleryTaskImpl) return false;
    return other.id == id;
  }

  @override
  String toString() {
    return 'TaskImp{$id,$status}';
  }
}

enum TaskStatus {
  UnStarted,
  Running,
  Finished,
}
