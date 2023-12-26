import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:logger/logger.dart';
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
  SendPort port;
  Logger? _logger;
  DownLoader(
      {required this.config,
      required this.api,
      required this.helper,
      required this.port,
      Logger? logger = null}) {
    this._logger = logger;
  }

  Future<bool> _downLoadGallery(_IdentifyToken token) async {
    var lastDate = DateTime.now();
    final void Function(Message msg) handle = (msg) async {
      switch (msg) {
        case GalleryMessage():
          {
            final path = join(config.output, msg.gallery.dirName);
            await helper.updateTask(
                msg.gallery.id, msg.gallery.dirName, path, false);
            this.port.send(msg);
            _logger?.d('down start $msg');
          }
        case DownLoadMessage():
          {
            var now = DateTime.now();
            if (now.difference(lastDate).inMilliseconds > 500) {
              lastDate = now;
              this.port.send(msg);
            }
          }
        case DownLoadFinished():
          {
            await helper.insertGallery(msg.gallery, msg.dirPath);
            this.port.send(msg);
            if (msg.success) {
              await helper.removeTask(msg.id);
            } else {
              final path = join(config.output, msg.gallery.dirName);
              await helper.updateTask(
                  msg.gallery.id, msg.gallery.dirName, path, true);
            }
            _runningTask.remove(token);
            _logger?.d('down finish $msg');
            _notifyTaskChange();
          }
        case IlleagalGallery():
          this.port.send(msg);
          _runningTask.remove(token);
          await helper.removeTask(msg.id);
          _logger?.d('down stop $msg');
          _notifyTaskChange();
      }
    };
    final f = token.id is Gallery
        ? api.downloadImages(token.id, onProcess: handle, token: token)
        : api.downloadImagesById(token.id,
            onProcess: handle, token: token, usePrefence: false);
    var b = await f.catchError((e) async {
      _logger?.e('$token catch error $e');
      await _downLoadGallery(token);
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

  void addTask(dynamic id) async {
    _logger?.d('add task $id');
    _pendingTask.add(id);
    if (id is Gallery) {
      var gallery = id;
      final path = join(config.output, gallery.dirName);
      await helper.updateTask(gallery.id, gallery.dirName, path, false);
    } else {
      await helper.updateTask(id, '', '', false);
    }
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
      _logger?.d('run task $id');
      var token = _IdentifyToken(id);
      _runningTask.add(token);
      _downLoadGallery(token);
    }
    _logger?.i(
        'left task ${_pendingTask.length} running task ${_runningTask.length}');
  }

  Future<Iterable<Gallery>> _fetchGalleryFromIds(
      List<int> ids, bool where(Gallery gallery), CancelToken token) async {
    if (ids.isNotEmpty) {
      final collection = await helper
          .selectSqlMultiResultAsync('select path from Gallery where id =?',
              ids.map((e) => [e]).toList())
          .then((value) {
        return Stream.fromIterable(value.entries)
            .asyncMap((event) async {
              final path = event.value.firstOrNull?['path'];
              final meta = File('$path/meta.json');
              if (path != null && meta.existsSync()) {
                var gallery = await meta
                    .readAsString()
                    .then((value) => Gallery.fromJson(value));
                if (where(gallery)) {
                  int hash = await imageHash(
                          File('$path/${gallery.files.first.name}')
                              .readAsBytesSync())
                      .catchError((e) => 0, test: (e) => true);
                  return Tuple2(hash, gallery);
                }
              } else {
                var gallery =
                    await api.fetchGallery(event.key[0], token: token);
                if (where(gallery)) {
                  int hash = await api
                      .downloadImage(api.getThumbnailUrl(gallery.files.first),
                          'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}',
                          token: token)
                      .then((value) => imageHash(Uint8List.fromList(value)))
                      .catchError((e) => 0, test: (e) => true);
                  return Tuple2(hash, gallery);
                }
              }
              return null;
            })
            .filterNonNull()
            .fold<List<Tuple2<int, Gallery>>>([], (previousValue, element) {
              var samilar = previousValue
                  .where((e) =>
                      compareHashDistance(e.item1, element.item1) < 8 ||
                      e.item2 == element.item2)
                  .toList();
              if (samilar.isEmpty ||
                  samilar
                      .where((e) =>
                          e.item2.chapterContains(element.item2) ||
                          compareHashDistance(e.item1, element.item1) < 8)
                      .isEmpty ||
                  samilar
                          .where(
                              (e) => e.item2.language == config.languages.first)
                          .isEmpty &&
                      element.item2.language == config.languages.first) {
                if (samilar.isNotEmpty) {
                  previousValue.removeWhere((tup) =>
                      samilar.any((e1) => e1.item2.id == tup.item2.id) &&
                      element.item2.chapterContains(tup.item2));
                }
                previousValue.add(element);
              }
              return previousValue;
            })
            .then((value) => value.map((e) => e.item2));
      });
      _logger?.d('search ids ${ids.length} fetch gallery ${collection.length}');
      return collection;
    }
    return [];
  }

  Future<CancelToken> downLoadByTag(
      List<Lable> tags, bool where(Gallery gallery)) async {
    if (exclude.length != config.excludes.length) {
      exclude.addAll(await helper.mapToLabel(config.excludes));
    }
    _logger?.d('fetch tags ${tags}');
    CancelToken token = CancelToken();
    final List<Gallery> results = await api
        .search(tags, exclude: exclude)
        .then((value) => _fetchGalleryFromIds(value, where, token))
        .then((value) async {
      _logger?.d('usefull result length ${value.length}');
      Map<List<dynamic>, ResultSet> map = value.isNotEmpty
          ? await helper.selectSqlMultiResultAsync(
              'select id from Gallery where id =?',
              value.map((e) => [e.id]).toList())
          : {};
      var r = value.groupListsBy((element) =>
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
                      e.dirName,
                      join(config.output, e.dirName),
                      false,
                    ])
                .toList());
      }
      return l;
    }).catchError((e) async {
      _logger?.e('$tags catch error $e');
      token.cancel();
      await downLoadByTag(tags, where);
      return <Gallery>[];
    },
            test: (error) =>
                error is DioException && error.message == null).catchError((e) {
      return <Gallery>[];
    });
    _logger?.d('${tags.first} find match gallery ${results.length}');
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
  String dirPath;
  DownLoadFinished(this.missFiles, this.gallery, this.dirPath,
      {required super.id, required super.success});
}

class IlleagalGallery extends Message<dynamic> {
  IlleagalGallery(dynamic id) : super(id: id, success: false);
}
