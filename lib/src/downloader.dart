import 'dart:isolate';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../gallery/gallery.dart';
import '../gallery/image.dart';
import '../gallery/label.dart';
import 'dhash.dart';
import 'hitomi.dart';
import 'sqlite_helper.dart';
import 'user_config.dart';

class DownLoader {
  final UserConfig config;
  final Hitomi api;
  final List<dynamic> pendingTask = [];
  final List<_IdentifyToken> _runningTask = <_IdentifyToken>[];
  final exclude = <Lable>[];
  final SqliteHelper helper;
  SendPort? port;
  DownLoader(
      {required this.config,
      required this.api,
      required this.helper,
      SendPort? port})
      : this.port = port;

  Future<bool> _downLoadGallery(_IdentifyToken token) async {
    var lastDate = DateTime.now();
    return await api.downloadImagesById(token.id, onProcess: (msg) async {
      switch (msg) {
        case GalleryMessage():
          {
            await helper.updateTask(msg.gallery, false);
          }
        case DownLoadMessage():
          {
            var now = DateTime.now();
            if (now.difference(lastDate).inMilliseconds > 300) {
              lastDate = now;
              this.port?.send(msg);
            }
          }
        case DownLoadFinished():
          {
            if (msg.success) {
              await helper.removeTask(msg.id);
            } else {
              await helper.updateTask(msg.gallery, true);
            }
            _runningTask.remove(token);
          }
      }
    }, token: token);
  }

  void addTask(dynamic id) {
    print('add task $id');
    pendingTask.add(id);
    _notifyTaskChange();
  }

  void cancel(dynamic id) {
    _runningTask
        .firstWhereOrNull((element) => element.id == id)
        ?.cancel('cancel');
    _notifyTaskChange();
  }

  void removeTask(dynamic id) {
    pendingTask.remove(id);
    cancel(id);
  }

  void _notifyTaskChange() async {
    if (_runningTask.length < config.maxTasks && pendingTask.isNotEmpty) {
      var id = pendingTask.removeAt(0);
      print('run task $id');
      var token = _IdentifyToken(id);
      _runningTask.add(token);
      await _downLoadGallery(token);
      _notifyTaskChange();
    }
  }

  Future<CancelToken> downLoadByTag(
      List<Lable> tags, bool where(Gallery gallery)) async {
    if (exclude.length != config.exinclude.length) {
      exclude.addAll(await helper.mapToLabel(config.exinclude));
    }
    CancelToken token = CancelToken();
    final List<Gallery> results =
        await api.search(tags, exclude: exclude).then((value) async {
      print('serch result length ${value.length}');
      return await Stream.fromIterable(value)
          .asyncMap(
              (event) async => await api.fetchGallery(event, token: token))
          .where((event) => where(event))
          .asyncMap((event) async {
        final img = await api.downloadImage(
            api.getThumbnailUrl(event.files.first),
            'https://hitomi.la${Uri.encodeFull(event.galleryurl!)}',
            token: token);
        var hash = await imageHash(Uint8List.fromList(img));
        return Tuple2(hash, event);
      }).fold<Map<Tuple2<int, Gallery>, Gallery>>({}, (previousValue, element) {
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
      }).then((value) async {
        var map = await helper.selectSqlMultiResultAsync(
            'select 1 from Gallery where id =?',
            value.values.map((e) => [e.id]).toList());
        var r = value.values.groupListsBy((element) =>
            map.entries
                .firstWhere((e) => e.key.equals([element.id]))
                .value
                .firstOrNull !=
            null);
        await helper.excuteSqlAsync(
            'replace into Tasks(id,title,path,completed) values(?,?,?,?)',
            r[false]
                    ?.map((e) => [
                          e.id,
                          e.fixedTitle,
                          join(config.output, e.fixedTitle),
                          false,
                        ])
                    .toList() ??
                []);
        return r[false]?.toList() ?? [];
      });
    });
    print('found match gallery ${results.length}');
    results.forEach((element) {
      addTask(element.id);
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
