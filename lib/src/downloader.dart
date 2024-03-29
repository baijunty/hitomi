import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dcache/dcache.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';

import '../gallery/gallery.dart';
import '../gallery/image.dart';
import '../gallery/label.dart';
import 'dir_scanner.dart';
import 'gallery_util.dart';
import 'sqlite_helper.dart';

class DownLoader {
  final _cache =
      SimpleCache<Label, Map<String, dynamic>>(storage: InMemoryStorage(1024));
  final UserConfig config;
  final Hitomi api;
  final Set<IdentifyToken> _pendingTask = <IdentifyToken>{};
  final Map<IdentifyToken, DownLoadingMessage> _runningTask = {};
  final exclude = <Label>[];
  final SqliteHelper helper;
  late IsolateManager<MapEntry<int, List<int>?>, String> manager;
  List<IdentifyToken> get pendingTask => [..._pendingTask];
  List<Map<String, dynamic>> get runningTask => _runningTask.entries
      .map((entry) => {
            'href': entry.key.gallery.galleryurl,
            'name': entry.key.gallery.dirName,
            ...entry.value.toMap
          })
      .toList();
  Logger? logger;
  final Dio dio;
  DownLoader(
      {required this.config,
      required this.api,
      required this.helper,
      required this.manager,
      required this.logger,
      required this.dio}) {
    final Future<bool> Function(Message msg) handle = (msg) async {
      var useHandle = await _runningTask.keys
          .firstWhereOrNull((e) => msg.id == e.gallery.id)
          ?.handle
          ?.call(msg);
      switch (msg) {
        case TaskStartMessage():
          {
            if (msg.target is Gallery) {
              // await translateLabel(msg.gallery.tags ?? []);
              return _findUnCompleteGallery(msg.gallery, msg.file as Directory)
                  .catchError((e) {
                logger?.e(e);
                return true;
              }, test: (error) => true).then((value) {
                if (value) {
                  return helper
                      .updateTask(msg.gallery.id, msg.gallery.dirName,
                          msg.file.path, false)
                      .then((value) =>
                          helper.insertGallery(msg.gallery, msg.file.path));
                }
                return false;
              });
            } else if (msg.target is Image) {
              return !msg.file.existsSync();
            }
            return illeagalTagsCheck(msg.gallery, config.excludes);
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
              return await helper.removeTask(msg.id);
            }
          }
        case DownLoadingMessage():
          {
            var key = _runningTask.keys
                .firstWhere((element) => element.gallery.id == msg.id);
            _runningTask[key] = msg;
          }
        default:
          break;
      }
      return useHandle ?? true;
    };
    api.registerCallBack(handle);
  }

  Future<Map<Label, Map<String, dynamic>>> translateLabel(
      List<Label> keys) async {
    var missed =
        keys.groupListsBy((element) => _cache[element] != null)[false] ?? [];
    if (missed.isNotEmpty) {
      var result = await helper.selectSqlMultiResultAsync(
          'select translate,intro,links from Tags where type=? and name=?',
          missed.map((e) => e.params).toList());
      missed.fold(_cache, (previousValue, element) {
        final v = result.entries
            .firstWhereOrNull((e) => e.key.equals(element.params))
            ?.value
            .firstOrNull;
        if (v != null) {
          previousValue[element] = {...v, ...element.toMap()};
        }
        return previousValue;
      });
    }
    missed =
        keys.groupListsBy((element) => _cache[element] != null)[false] ?? [];
    if (missed.isNotEmpty) {
      await Future.wait(missed.toSet().map((event) => dio
              .httpInvoke<List<dynamic>>(
                  'https://translate.googleapis.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=zh&q=${event.name}')
              .then((value) {
            final v = value[0][0] as String;
            _cache[event] = {'translate': v, ...event.toMap()};
            logger?.d('${event.name} translate to $v');
            return v;
          })));
    }
    final r = keys.fold(
        <Label, Map<String, dynamic>>{},
        (previousValue, element) =>
            previousValue..[element] = _cache[element]!);
    return r;
  }

  Future<bool> _findUnCompleteGallery(Gallery gallery, Directory newDir) async {
    if (newDir.listSync().isNotEmpty) {
      return readGalleryFromPath(newDir.path).then((value) {
        logger?.d('${newDir.path} $gallery exists $value ');
        return (compareGallerWithOther(value, [gallery], config.languages).id !=
                value.id) ||
            (newDir.listSync().length - 1) != value.files.length;
      }).catchError((e) => true, test: (error) => true);
    } else
      return findDuplicateGalleryIds(gallery, helper, api, logger: logger)
          .then((value) {
        if (value.isNotEmpty) {
          logger?.i('found duplicate with $value');
          return Future.wait(value.map((e) => helper.queryGalleryById(e).then((value) =>
                  readGalleryFromPath(join(config.output, value.first['path']))
                      .then((value) => value.createDir(config.output, createDir: false)))))
              .then((value) => value.every((element) =>
                  !element.existsSync() || element.listSync().length < 18));
        }
        // if (value.isEmpty) {
        //   return findDuplicateGalleryIds(gallery, helper, api,
        //           logger: logger, skipTail: true)
        //       .then((value) => value.firstOrNull)
        //       .then((value) {
        //     if (value != null) {
        //       helper
        //           .queryGalleryById(value)
        //           .then((value) => readGalleryFromPath(
        //               join(config.output, value.first['path'])))
        //           .then((value) => value.createDir(config.output))
        //           .then((dir) {
        //         logger?.i(
        //             '$value with ${dir.path} hash newer ${gallery.id} ${newDir.path}');
        //         dir.renameSync(newDir.path);
        //         return false;
        //       }).catchError((e) => false, test: (error) => true);
        //     }
        //     return false;
        //   });
        // }
        return value.isEmpty;
      });
  }

  bool illeagalTagsCheck(Gallery gallery, List<FilterLabel> excludes) {
    final labels = gallery.labels();
    var illeagalTags =
        excludes.where((element) => labels.contains(element)).toList();
    if (excludes.any(
        (element) => illeagalTags.contains(element) && element.weight >= 1.0)) {
      logger?.w('${gallery.id} found forbidden tag');
      return false;
    }
    final weight = illeagalTags.fold(0.0, (acc, e) => acc + e.weight);
    final checkResult = weight <= illeagalTags.length / labels.length &&
        pow(10, illeagalTags.length) * 2 / gallery.files.length < 0.5;
    logger?.d(
        '${gallery.id} weight $weight files ${gallery.files.length} result $checkResult');
    return checkResult;
  }

  Future<bool> _downLoadGallery(IdentifyToken token) async {
    var b = await api.downloadImages(token.gallery, token: token).catchError(
        (e) async {
      logger?.e('$token catch error $e');
      return false;
    }, test: (e) => true);
    _runningTask.remove(token);
    _notifyTaskChange();
    return b;
  }

  Future<IdentifyToken> addTask(Gallery gallery) async {
    logger!.d('add task ${gallery.id}');
    var token = IdentifyToken(gallery);
    _pendingTask.add(token);
    final path = join(config.output, gallery.dirName);
    await helper.updateTask(gallery.id, gallery.dirName, path, false);
    _notifyTaskChange();
    return token;
  }

  void cancelByTag(Label label) {
    final tokens = _runningTask.keys
        .where((element) => element.gallery.labels().contains(label))
        .toList();
    tokens.forEach((element) {
      element.cancel('cancel');
    });
    logger!.d('cacel task $label');
    _runningTask.removeWhere((element, v) => tokens.contains(element));
    _pendingTask
        .removeWhere((element) => element.gallery.labels().contains(label));
    _notifyTaskChange();
  }

  IdentifyToken? operator [](dynamic key) {
    return _runningTask.keys
            .firstWhereOrNull((element) => element.gallery.id == key) ??
        _pendingTask.firstWhereOrNull((element) => element.gallery.id == key);
  }

  void cancelAll() {
    _runningTask.forEach((element, value) {
      element.cancel();
    });
    _pendingTask.addAll(_runningTask.keys);
    _runningTask.clear();
  }

  void removeTask(dynamic id) {
    _pendingTask.removeWhere((g) => g.gallery.id == id);
    _runningTask.keys
        .firstWhereOrNull((element) => element.gallery.id == id)
        ?.cancel('cancel');
  }

  void _notifyTaskChange() async {
    while (_runningTask.length < config.maxTasks && _pendingTask.isNotEmpty) {
      var token = _pendingTask.first;
      _pendingTask.remove(token);
      logger?.d('run task ${token.gallery.id} length ${_runningTask.length}');
      _runningTask[token] =
          DownLoadingMessage(token.gallery, 0, 0, token.gallery.files.length);
      _downLoadGallery(token);
    }
    logger?.i(
        'left task ${_pendingTask.length} running task ${_runningTask.length}');
  }

  Future<List<Gallery>> fetchGalleryFromIds(
      List<int> ids, bool where(Gallery gallery), CancelToken token) async {
    if (ids.isNotEmpty) {
      logger?.d('fetch gallery from ids ${ids.length}');
      return helper
          .selectSqlMultiResultAsync('select id,path from Gallery where id =?',
              ids.map((e) => [e]).toList())
          .then((value) => Stream.fromIterable(value.entries)
              .asyncMap((event) async {
                try {
                  String? path = event.value.firstOrNull?['path'];
                  var fromNet = api.fetchGallery(event.key[0],
                      usePrefence: false, token: token);
                  var gallery = path != null
                      ? await readGalleryFromPath(join(config.output, path))
                          .catchError((e) async {
                          logger?.e('read json $e');
                          return fromNet;
                        }, test: (error) => true)
                      : await fromNet;
                  if (gallery.id == event.key[0]) {
                    return gallery;
                  }
                } catch (e, stack) {
                  logger?.e('fetch gallery $e with $stack');
                }
              })
              .filterNonNull()
              .where((event) => where(event))
              .fold(<Gallery>[], (previous, element) {
                if (previous.any((pre) =>
                    pre.languages?.any((lang) =>
                            lang.galleryid == element.id.toString() &&
                            max(0, config.languages.indexOf(lang.name)) <=
                                max(
                                    0,
                                    config.languages
                                        .indexOf(element.language!))) ==
                        true &&
                    (pre.files.length - element.files.length).abs() < 4)) {
                  return previous;
                }
                return previous..add(element);
              }));
    }
    return [];
  }

  Future<List<Gallery>> filterGalleryByImageHash(List<Gallery> list,
      CancelToken token, MapEntry<String, String>? entry) async {
    Map<int, List<int>> allHash = entry != null
        ? await helper.queryImageHashsByLabel(entry.key, entry.value)
        : {};
    logger?.d('ids ${list.length} $entry found ${allHash.keys.toList()} in db');
    list.sort((e1, e2) => e2.files.length - e1.files.length);
    return list
        .asStream()
        .asyncMap((event) =>
            fetchGalleryHash(event, helper, api, token, true, config.output))
        .where((event) => searchSimilerGaller(
                MapEntry(event.key.id, event.value), allHash, logger: logger)
            .isEmpty)
        .fold(<int, List<int>>{}, (previous, element) {
          var duplicate = searchSimilerGaller(
              MapEntry(element.key.id, element.value), previous,
              logger: logger);
          logger?.d('${entry} scan ${element.key.id} count ${previous.length}');
          if (duplicate.isEmpty) {
            previous[element.key.id] = element.value;
          } else {
            var compare = duplicate
                .map((event) =>
                    list.firstWhere((element) => element.id == event))
                .toList();
            var useGallery = compareGallerWithOther(
                element.key, compare, config.languages, logger);
            if (useGallery.id == element.key.id) {
              previous[useGallery.id] = element.value;
              previous.removeWhere((key, value) => duplicate.contains(key));
            }
            logger?.d(
                '${element.key} found ${duplicate} use ${useGallery} count ${previous.length}');
          }
          return previous;
        })
        .then((downHash) {
          logger?.d('${downHash.length} not in local');
          return downHash.keys;
        })
        .then((value) => value
            .map((event) => list.firstWhere((element) => element.id == event))
            .toList())
        .catchError((err) {
          logger?.e(err);
          return <Gallery>[];
        }, test: (error) => true);
  }

  Future<bool> downLoadByTag(List<Label> tags, bool where(Gallery gallery),
      MapEntry<String, String> entry, CancelToken token,
      {void Function(bool success)? onFinish}) async {
    if (exclude.length != config.excludes.length) {
      exclude.addAll(config.excludes);
    }
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
    }).then((value) {
      if (onFinish != null) {
        final result = <int, bool>{};
        late Future<bool> Function(Message msg) handle;
        handle = (msg) async {
          if (msg is DownLoadFinished) {
            result[msg.gallery.id] = msg.success;
            if (result.length == value.length) {
              onFinish.call(result.values.reduce(
                  (previousValue, element) => previousValue && element));
              api.removeCallBack(handle);
            }
          }
          return true;
        };
        if (value.isNotEmpty) {
          api.registerCallBack(handle);
        } else {
          onFinish.call(true);
        }
      }
      return Future.wait(value.map((e) => addTask(e)));
    });
    logger?.i('${tags.first} find match gallery ${results.length}');
    return results.isNotEmpty;
  }

  Future<List<Gallery>> fetchGallerysByTags(
      List<Label> tags,
      bool where(Gallery gallery),
      CancelToken token,
      MapEntry<String, String>? entry) async {
    logger?.d('fetch tags ${tags}');
    return await api
        .search(tags, exclude: exclude)
        .then((value) => fetchGalleryFromIds(value.data, where, token))
        .then((value) => filterGalleryByImageHash(value, token, entry))
        .catchError((e) async {
      logger?.e('$tags catch error $e');
      return fetchGallerysByTags(tags, where, token, entry);
    },
            test: (error) =>
                error is DioException && error.message == null).catchError((e) {
      logger?.e('$tags uncatch error $e');
      return <Gallery>[];
    }, test: (error) => true);
  }
}

class IdentifyToken extends CancelToken {
  final Gallery gallery;
  Future<bool> Function(Message msg)? handle = null;
  IdentifyToken(this.gallery);
}
