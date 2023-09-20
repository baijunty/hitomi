import 'dart:isolate';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tuple/tuple.dart';

import '../gallery/gallery.dart';
import '../gallery/image.dart';
import '../gallery/label.dart';
import 'dhash.dart';
import 'sqlite_helper.dart';

class DownLoader {
  final UserConfig config;
  final Hitomi api;
  final List<dynamic> _pendingTask = [];
  final List<_IdentifyToken> _runningTask = <_IdentifyToken>[];
  final exclude = <Lable>[];
  final SqliteHelper helper;
  List<dynamic> get tasks =>
      [..._pendingTask, ..._runningTask.map((e) => e.id)];
  SendPort? port;
  DownLoader(
      {required this.config,
      required this.api,
      required this.helper,
      SendPort? port})
      : this.port = port;

  Future<bool> _downLoadGallery(_IdentifyToken token) async {
    var lastDate = DateTime.now();
    final void Function(Message msg) handle = (msg) async {
      switch (msg) {
        case GalleryMessage():
          {
            await helper.updateTask(msg.gallery, false);
          }
        case DownLoadMessage():
          {
            var now = DateTime.now();
            if (now.difference(lastDate).inMilliseconds > 500) {
              lastDate = now;
              this.port?.send(msg);
            }
          }
        case DownLoadFinished():
          {
            await helper.insertGallery(msg.gallery);
            if (msg.success) {
              await helper.removeTask(msg.id);
            } else {
              await helper.updateTask(msg.gallery, true);
            }
            _runningTask.remove(token);
            _notifyTaskChange();
          }
        case IlleagalGallery():
          _runningTask.remove(token);
          await helper.removeTask(msg.id);
          _notifyTaskChange();
      }
    };
    final f = token.id is Gallery
        ? api.downloadImages(token.id, onProcess: handle, token: token)
        : api.downloadImagesById(token.id, onProcess: handle, token: token);
    var b = await f.catchError((e) {
      print(e);
      _downLoadGallery(token);
      return false;
    },
        test: (error) =>
            error is DioException && error.message == null).catchError(
        (e) async {
      _runningTask.remove(token);
      return false;
    }, test: (e) => true);
    return b;
  }

  void addTask(dynamic id) {
    print('add task $id');
    _pendingTask.add(id);
    _notifyTaskChange();
  }

  void cancel(dynamic id) {
    final token = _runningTask.firstWhereOrNull((element) => element.id == id);
    token?.cancel('cancel');
    _runningTask.remove(token);
    _notifyTaskChange();
  }

  void removeTask(dynamic id) {
    _pendingTask.remove(id);
    cancel(id);
  }

  void _notifyTaskChange() async {
    while (_runningTask.length < config.maxTasks && _pendingTask.isNotEmpty) {
      var id = _pendingTask.removeAt(0);
      print('run task $id');
      var token = _IdentifyToken(id);
      _runningTask.add(token);
      _downLoadGallery(token);
    }
    print(
        'left task ${_pendingTask.length} running task ${_runningTask.length}');
  }

  Future<CancelToken> downLoadByTag(
      List<Lable> tags, bool where(Gallery gallery)) async {
    if (exclude.length != config.exinclude.length) {
      exclude.addAll(await helper.mapToLabel(config.exinclude));
    }
    CancelToken token = CancelToken();
    final List<Gallery> results = await api
        .search(tags, exclude: exclude)
        .then((value) async {
      print('serch result length ${value.length}');
      return await Stream.fromIterable(value)
          .asyncMap(
              (event) async => await api.fetchGallery(event, token: token))
          .distinct((g1, g2) => g1.id == g2.id)
          .where((event) => where(event))
          .fold(<dynamic, Gallery>{},
              (previous, element) => previous..[element.id] = element)
          .then((value) => value.values)
          .then((event) async {
            print('left result length ${event.length}');
            return event.asStream().asyncMap((event) async {
              final img = await api.downloadImage(
                  api.getThumbnailUrl(event.files.first),
                  'https://hitomi.la${Uri.encodeFull(event.galleryurl!)}',
                  token: token);
              var hash = await imageHash(Uint8List.fromList(img));
              return Tuple2(hash, event);
            }).fold<Map<Tuple2<int, Gallery>, Gallery>>({},
                (previousValue, element) {
              previousValue.removeWhere((key, value) {
                if ((compareHashDistance(key.item1, element.item1) < 8 ||
                        key.item2 == element.item2) &&
                    (element.item2.language == 'japanese' ||
                        element.item2.language == value.language)) {
                  return true;
                }
                return false;
              });
              previousValue[element] = element.item2;
              return previousValue;
            });
          })
          .then((value) async {
            print('usefull result length ${value.values.length}');
            Map<List<dynamic>, ResultSet> map = value.values.isNotEmpty
                ? await helper.selectSqlMultiResultAsync(
                    'select id from Gallery where id =?',
                    value.values.map((e) => [e.id]).toList())
                : {};
            var r = value.values.groupListsBy((element) =>
                map.entries
                    .firstWhere((e) => e.key.equals([element.id]))
                    .value
                    .firstOrNull !=
                null);
            var l = r[false] ?? [];
            if (l.isNotEmpty) {
              await helper.excuteSqlAsync(
                  'replace into Tasks(id,title,path,completed) values(?,?,?,?)',
                  l
                      .map((e) => [
                            e.id,
                            e.fixedTitle,
                            join(config.output, e.fixedTitle),
                            false,
                          ])
                      .toList());
            }
            return l;
          });
    }).catchError((e) {
      print(e);
      token.cancel();
      downLoadByTag(tags, where);
      return <Gallery>[];
    },
            test: (error) =>
                error is DioException && error.message == null).catchError((e) {
      print(e);
      return <Gallery>[];
    });
    print('find match gallery ${results.length}');
    results.forEach((element) {
      addTask(element);
    });
    return token;
  }
}

class _IdentifyToken extends CancelToken {
  final dynamic id;

  _IdentifyToken(this.id);
}

sealed class Message<T> {
  final T id;
  bool success;
  Message({required this.id, required this.success});

  @override
  String toString() {
    return 'Message{$id,$success}';
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this)) return true;
    if (other is! Message) return false;
    return other.id == id;
  }
}

class GalleryMessage extends Message<dynamic> {
  Gallery gallery;
  GalleryMessage(this.gallery, {required super.id, required super.success});
}

class DownLoadMessage extends Message<dynamic> {
  int current;
  int maxPage;
  double speed;
  int length;
  String title;
  DownLoadMessage(id, success, this.title, this.current, this.maxPage,
      this.speed, this.length)
      : super(id: id, success: success);
  @override
  String toString() {
    return 'DownLoadMessage{$id,$title,$current $maxPage,$speed,$length,$success}';
  }
}

class DownLoadFinished extends Message<dynamic> {
  List<Image> missFiles;
  Gallery gallery;
  DownLoadFinished(this.missFiles, this.gallery,
      {required super.id, required super.success});
}

class IlleagalGallery extends Message<dynamic> {
  IlleagalGallery(dynamic id) : super(id: id, success: false);
}
