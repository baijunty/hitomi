import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dcache/dcache.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';

import '../gallery/gallery.dart';
import '../gallery/image.dart';
import '../gallery/label.dart';
import 'dhash.dart';
import 'dir_scanner.dart';
import 'gallery_util.dart';
import 'sqlite_helper.dart';

class DownLoader {
  final _cache = SimpleCache(storage: InMemoryStorage(1024));
  final UserConfig config;
  final Hitomi api;
  final Set<Gallery> _pendingTask = <Gallery>{};
  final List<_IdentifyToken> _runningTask = <_IdentifyToken>[];
  final exclude = <Lable>[];
  final SqliteHelper helper;
  late IsolateManager<MapEntry<int, List<int>?>, String> manager;
  List<dynamic> get tasks =>
      [..._pendingTask, ..._runningTask.map((e) => e.id)];
  Logger? logger;
  DownLoader(
      {required this.config,
      required this.api,
      required this.helper,
      required this.manager,
      required this.logger}) {
    final Future<bool> Function(Message msg) handle = (msg) async {
      switch (msg) {
        case TaskStartMessage():
          {
            if (msg.target is Gallery) {
              // await translateLabel(msg.gallery.tags ?? []);
              logger?.d('down start $msg');
              var b = await _findUnCompleteGallery(
                      msg.gallery, msg.file as Directory)
                  .catchError((e) {
                logger?.e(e);
                logger?.e(StackTrace.current);
                return true;
              }, test: (error) => true);
              if (!b) {
                await helper
                    .updateTask(msg.gallery.id, msg.gallery.dirName,
                        msg.file.path, false)
                    .then((value) =>
                        helper.insertGallery(msg.gallery, msg.file.path));
              }
              return b;
            } else if (msg.target is Image) {
              return !msg.file.existsSync();
            }
            return containsIlleagalTags(
                msg.gallery, config.excludes.keys.toList());
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
              logger?.i('down finish ${msg}');
              return HitomiDir(
                      msg.file as Directory, this, msg.gallery, manager,
                      fixFromNet: false)
                  .fixGallery();
            } else if (msg.target is Image) {
              return manager.compute(msg.file.path).then((value) =>
                  helper.insertGalleryFile(
                      msg.gallery, msg.target, value.key, value.value));
            } else if (msg.target is Gallery) {
              logger?.w('illeagal gallery ${msg.id}');
              return HitomiDir(
                      msg.file as Directory, this, msg.gallery, manager,
                      fixFromNet: false)
                  .deleteGallery()
                  .then((value) => helper.removeTask(msg.id))
                  .then((value) => helper.deleteGallery(msg.id));
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
      var result = await helper.selectSqlMultiResultAsync(
          'select translate from Tags where type=? and name=?',
          missed.map((e) => e.params).toList());
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
      await Future.wait(missed.toSet().map((event) => api
              .httpInvoke<List<dynamic>>(
                  'https://translate.googleapis.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=zh&q=${event.name}')
              .then((value) {
            final v = value[0][0] as String;
            _cache[event] = v;
            logger?.d('${event.name} translate to $v');
            return v;
          })));
    }
    keys.forEach((element) {
      element.translate = _cache[element];
    });
    return keys;
  }

  Future<bool> _findUnCompleteGallery(Gallery gallery, Directory newDir) async {
    return findDuplicateGalleryIds(gallery, helper, api,
            logger: logger, skipTail: false)
        .then((value) {
      if (value.isEmpty) {
        return findDuplicateGalleryIds(gallery, helper, api,
                logger: logger, skipTail: true)
            .then((value) => value.firstOrNull)
            .then((value) {
          if (value != null) {
            helper
                .queryGalleryById(value)
                .then((value) => readGalleryFromPath(
                    join(config.output, value.first['path'])))
                .then((value) => value.createDir(config.output))
                .then((dir) {
              logger?.i(
                  '$value with ${dir.path} hash newer ${gallery.id} ${newDir.path}');
              dir.renameSync(newDir.path);
              return false;
            }).catchError((e) => false, test: (error) => true);
          }
          return false;
        });
      }
      return value.isNotEmpty;
    });
  }

  bool containsIlleagalTags(Gallery gallery, List<String> excludes) {
    var illeagalTags = gallery.tags
            ?.where((element) => excludes.contains(element.name))
            .toList() ??
        [];
    if (illeagalTags.isNotEmpty) {
      logger?.i(
          '${gallery.id} found ${illeagalTags.map((e) => e.name).toList()} ${gallery.files.length}');
    }
    return illeagalTags
            .any((element) => config.excludes[element.name] ?? false) ||
        pow(10, illeagalTags.length) / gallery.files.length >= 0.5;
  }

  Future<bool> _downLoadGallery(_IdentifyToken token) async {
    var b =
        await api.downloadImages(token.id, token: token).catchError((e) async {
      logger?.e('$token catch error $e');
      return false;
    }, test: (e) => true);
    _runningTask.remove(token);
    _notifyTaskChange();
    return b;
  }

  void addTask(Gallery gallery) async {
    logger!.d('add task ${gallery.id}');
    _pendingTask.add(gallery);
    final path = join(config.output, gallery.dirName);
    await helper.updateTask(gallery.id, gallery.dirName, path, false);
    _notifyTaskChange();
  }

  void cancel(dynamic id) {
    final token = _runningTask.firstWhereOrNull(
        (element) => element.id.id.toString() == id.toString());
    token?.cancel('cancel');
    logger!.d('cacel task ${token?.id}');
    _runningTask.remove(token);
    _notifyTaskChange();
  }

  void cancelByTag(Lable lable) {
    final tokens = _runningTask
        .where((element) => element.id.lables().contains(lable))
        .toList();
    tokens.forEach((element) {
      element.cancel('cancel');
    });
    logger!.d('cacel task $lable');
    _runningTask.removeWhere((element) => tokens.contains(element));
    _pendingTask.removeWhere((element) => element.lables().contains(lable));
    _notifyTaskChange();
  }

  void cancelAll() {
    _runningTask.forEach((element) {
      element.cancel();
    });
    _pendingTask.addAll(_runningTask.map((e) => e.id));
    _runningTask.clear();
  }

  void removeTask(dynamic id) {
    _pendingTask.removeWhere((g) => g.id.toString() == id.toString());
    cancel(id);
  }

  void _notifyTaskChange() async {
    while (_runningTask.length < config.maxTasks && _pendingTask.isNotEmpty) {
      var id = _pendingTask.first;
      _pendingTask.remove(id);
      logger?.d('run task $id length ${_runningTask.length}');
      var token = _IdentifyToken(id);
      _runningTask.add(token);
      _downLoadGallery(token);
    }
    logger?.i(
        'left task ${_pendingTask.length} running task ${_runningTask.length}');
  }

  Future<Gallery> readGalleryFromPath(String path) {
    return File(join(path, 'meta.json'))
        .readAsString()
        .then((value) => Gallery.fromJson(value));
  }

  Future<Iterable<Gallery>> _fetchGalleryFromIds(
      List<int> ids,
      bool where(Gallery gallery),
      CancelToken token,
      MapEntry<String, String>? entry) async {
    if (ids.isNotEmpty) {
      Map<int, List<int>> allHash = entry != null
          ? await helper.queryImageHashsByLable(entry.key, entry.value)
          : {};
      logger
          ?.d('ids ${ids.length} $entry found ${allHash.keys.toList()} in db');
      ids.removeWhere((element) => allHash.keys.contains(element));
      final collection = await helper
          .selectSqlMultiResultAsync('select id,path from Gallery where id =?',
              ids.map((e) => [e]).toList())
          .then((value) async {
        var list = await Future.wait(value.entries.map((event) {
          String? path = event.value.firstOrNull?['path'];
          return path != null
              ? readGalleryFromPath(join(config.output, path)).catchError(
                  (e) async {
                  logger?.e('read json $e');
                  return await api.fetchGallery(event.key[0], token: token);
                }, test: (error) => true)
              : api.fetchGallery(event.key[0], token: token);
        })).then((value) => value.where((element) => where(element)).toList());
        return list
            .asStream()
            .asyncMap((event) => fetchLocalGalleryHash(event, helper))
            .asyncMap((event) async => event.value.isEmpty
                ? await fetchNetGalleryHash(event.key, api, token)
                : event)
            .where((event) => searchSimilerGaller(
                    MapEntry(event.key.id, event.value), allHash,
                    logger: logger)
                .isEmpty)
            .fold(
                <int, List<int>>{},
                (previous, element) => previous
                  ..[element.key.id] = element.value).then((downHash) {
          logger?.d(' ${downHash.keys.toList()} not in local');
          var useHash =
              downHash.entries.fold(<int, List<int>>{}, (previous, element) {
            var duplicate =
                searchSimilerGaller(element, previous, logger: logger);
            if (duplicate.isEmpty) {
              previous[element.key] = element.value;
            } else {
              var compare = duplicate
                  .map((event) =>
                      list.firstWhere((element) => element.id == event))
                  .toList();
              var useGallery = compareGallerWithOther(
                  list.firstWhere((event) => event.id == element.key),
                  compare,
                  config.languages,
                  logger);
              logger?.d(
                  ' ${element.key} find similer $duplicate use ${useGallery.id}');
              if (useGallery.id == element.key) {
                previous[useGallery.id] = element.value;
                previous.removeWhere((key, value) => duplicate.contains(key));
              } else {
                previous.remove(useGallery.id);
                previous[useGallery.id] = downHash[useGallery.id]!;
              }
            }
            return previous;
          });
          return useHash.keys;
        }).then((value) => value
                .map((event) =>
                    list.firstWhere((element) => element.id == event))
                .toList());
      });
      logger?.d('search ids ${ids.length} fetch gallery ${collection.length}');
      return collection;
    }
    return [];
  }

  Future<CancelToken> downLoadByTag(List<Lable> tags,
      bool where(Gallery gallery), MapEntry<String, String> entry) async {
    if (exclude.length != config.excludes.length) {
      exclude.addAll(await helper.mapToLabel(config.excludes.keys.toList()));
    }
    CancelToken token = CancelToken();
    final results = await fetchGallerysByTags(tags, where, token, entry)
        .then((value) async {
      logger?.d('usefull result length ${value.length}');
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
        await helper.excuteSqlMultiParams(
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
    });
    logger?.i('${tags.first} find match gallery ${results.length}');
    results.forEach((element) {
      addTask(element);
    });
    return token;
  }

  Future<List<Gallery>> fetchGallerysByTags(
      List<Lable> tags,
      bool where(Gallery gallery),
      CancelToken token,
      MapEntry<String, String>? entry) async {
    logger?.d('fetch tags ${tags}');
    return await api
        .search(tags, exclude: exclude)
        .then((value) => _fetchGalleryFromIds(value, where, token, entry))
        .then((value) => value.toList())
        .catchError((e) async {
      logger?.e('$tags catch error $e');
      token.cancel();
      await fetchGallerysByTags(tags, where, token, entry);
      return <Gallery>[];
    },
            test: (error) =>
                error is DioException && error.message == null).catchError((e) {
      logger?.e('$tags uncatch error $e');
      return <Gallery>[];
    });
  }
}

class _IdentifyToken extends CancelToken {
  final Gallery id;

  _IdentifyToken(this.id);
}
