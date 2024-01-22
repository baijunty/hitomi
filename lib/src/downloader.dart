import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dcache/dcache.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tuple/tuple.dart';

import '../gallery/gallery.dart';
import '../gallery/label.dart';
import 'dhash.dart';
import 'dir_scanner.dart';
import 'sqlite_helper.dart';

class DownLoader {
  final _cache = SimpleCache(storage: InMemoryStorage(1024));
  final UserConfig config;
  final Hitomi api;
  final Set<Gallery> _pendingTask = <Gallery>{};
  final List<_IdentifyToken> _runningTask = <_IdentifyToken>[];
  final exclude = <Lable>[];
  final SqliteHelper helper;
  List<dynamic> get tasks =>
      [..._pendingTask, ..._runningTask.map((e) => e.id)];
  Logger? _logger;
  DownLoader(
      {required this.config,
      required this.api,
      required this.helper,
      Logger? logger = null}) {
    this._logger = logger;
    final Future<bool> Function(Message msg) handle = (msg) async {
      switch (msg) {
        case TaskStartMessage():
          {
            if (msg.target is Gallery) {
              await translateLabel(msg.gallery.tags ?? []);
              await helper.updateTask(
                  msg.gallery.id, msg.gallery.dirName, msg.file.path, false);
              await helper.insertGallery(msg.gallery, msg.file.path);
              await _findUnCompleteGallery(msg.gallery, msg.file as Directory);
              _logger?.d('down start $msg');
            } else {
              return !msg.file.existsSync();
            }
          }
        case DownLoadFinished():
          {
            if (msg.target is List) {
              if (msg.success) {
                await helper.removeTask(msg.id);
              } else {
                await helper.updateTask(
                    msg.gallery.id, msg.gallery.dirName, msg.file.path, true);
              }
              _logger?.d('down finish $msg');
              return HitomiDir(msg.file as Directory, config, helper,
                      msg.gallery, this._logger)
                  .removeIllegalFile();
            }
          }
        default:
          break;
      }
      return true;
    };
    api.registerGallery(handle);
  }

  Future<List<Lable>> translateLabel(List<Lable> keys) async {
    var missed =
        keys.groupListsBy((element) => _cache[element] != null)[false] ?? [];
    if (missed.isNotEmpty) {
      final params = missed.map((e) => e.params).toList();
      var result = await helper.selectSqlMultiResultAsync(
          'select translate from Tags where type=? and name=?', params);
      missed.fold(_cache, (previousValue, element) {
        final v = result.entries
            .firstWhereOrNull((e) => e.key.equals(element.params))
            ?.value
            .firstOrNull?['translate'];
        previousValue[element] = v;
        return previousValue;
      });
    }
    missed =
        keys.groupListsBy((element) => _cache[element] != null)[false] ?? [];
    if (missed.isNotEmpty) {
      await Stream.fromIterable(missed.toSet()).asyncMap((event) async {
        await api
            .http_invke(
                'https://translate.googleapis.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=zh&q=${event.name}')
            .then((ints) {
              return Utf8Decoder().convert(ints);
            })
            .then((value) => json.decode(value))
            .then((value) {
              _logger?.d(value);
              final v = value[0][0] as String;
              _cache[event] = v;
              return v;
            });
      }).toList();
    }
    keys.forEach((element) {
      element.translate = _cache[element];
    });
    return keys;
  }

  Future<void> _findUnCompleteGallery(Gallery gallery, Directory newDir) async {
    var r = await helper.querySql(
        'select * from Gallery where (author=? or groupes=?) order by id desc',
        [gallery.artists?.first.name, gallery.groups?.first.name]);
    if (r?.isNotEmpty == true) {
      int hash = await api
          .downloadImage(api.getThumbnailUrl(gallery.files.first),
              'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}')
          .then((value) => imageHash(Uint8List.fromList(value)))
          .catchError((e) => 0, test: (e) => true);
      var befor = r!
          .where((element) => compareHashDistance(element['hash'], hash) < 8)
          .map((e) => Gallery.fromJson(
              File("${e['path']}/meta.json").readAsStringSync()))
          .firstWhereOrNull((element) =>
              gallery.nameFixed == element.nameFixed &&
              gallery.chapterContains(element));
      if (befor != null) {
        var dir = Directory('${config.output}/${befor.dirName}');
        if (dir.existsSync() && newDir.listSync().length <= 2) {
          newDir.deleteSync(recursive: true);
          dir.renameSync(newDir.path);
        }
      }
    }
  }

  Future<bool> _downLoadGallery(_IdentifyToken token) async {
    final f = api.downloadImages(token.id, token: token);
    var b = await f.catchError((e) async {
      _logger?.e('$token catch error $e');
      return false;
    }, test: (e) => true);
    _runningTask.remove(token);
    return b;
  }

  void addTask(Gallery gallery) async {
    _logger?.d('add task ${gallery.id}');
    _pendingTask.add(gallery);
    final path = join(config.output, gallery.dirName);
    await helper.updateTask(gallery.id, gallery.dirName, path, false);
    _notifyTaskChange();
  }

  void cancel(dynamic id) {
    final token = _runningTask
        .firstWhereOrNull((element) => element.id.toString() == id.toString());
    token?.cancel('cancel');
    _runningTask.remove(token);
    _notifyTaskChange();
  }

  void removeTask(dynamic id) {
    _pendingTask.removeWhere((g) => g.id.toString() == id.toString());
    cancel(id);
  }

  void _notifyTaskChange() async {
    while (_runningTask.length < config.maxTasks && _pendingTask.isNotEmpty) {
      var id = _pendingTask.first;
      _pendingTask.remove(id);
      _logger?.d('run task $id');
      var token = _IdentifyToken(id);
      _runningTask.add(token);
      await _downLoadGallery(token);
      _logger?.i(
          'left task ${_pendingTask.length} running task ${_runningTask.length}');
      _notifyTaskChange();
    }
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
  final Gallery id;

  _IdentifyToken(this.id);
}

sealed class Message<T> {
  final T id;
  Message({required this.id});

  @override
  String toString() {
    return 'Message {$id}';
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this)) return true;
    if (other is! Message) return false;
    return other.id == id;
  }
}

class TaskStartMessage<T> extends Message<dynamic> {
  Gallery gallery;
  FileSystemEntity file;
  T target;
  TaskStartMessage(this.gallery, this.file, this.target)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'TaskStartMessage{$id,${file.path},${target}, ${gallery.files.length} }';
  }
}

class DownLoadingMessage extends Message<dynamic> {
  Gallery gallery;
  int current;
  double speed;
  int length;
  DownLoadingMessage(this.gallery, this.current, this.speed, this.length)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'DownLoadMessage{$id,$current $speed,$length }';
  }
}

class DownLoadFinished<T> extends Message<dynamic> {
  Gallery gallery;
  FileSystemEntity file;
  T target;
  bool success;
  DownLoadFinished(this.target, this.gallery, this.file, this.success)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'DownLoadingMessage{$id,${file.path},${target} }';
  }
}

class IlleagalGallery extends Message<dynamic> {
  String errorMsg;
  int index;
  IlleagalGallery(dynamic id, this.errorMsg, this.index) : super(id: id);
}
