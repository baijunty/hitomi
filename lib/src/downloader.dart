import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/imagetagfeature.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';

import '../gallery/gallery.dart';
import '../gallery/image.dart';
import '../gallery/label.dart';
import 'dir_scanner.dart';
import 'gallery_util.dart';

class DownLoader {
  final UserConfig config;
  final Hitomi api;
  final Set<IdentifyToken> _pendingTask = <IdentifyToken>{};
  final Map<IdentifyToken, DownLoadingMessage> _runningTask =
      <IdentifyToken, DownLoadingMessage>{};
  final SqliteHelper helper;
  late DateTime limit;
  late bool Function(Gallery) filter;
  final Function(Map<String, dynamic> msg) taskObserver;
  final TaskManager manager;
  Logger? logger;

  Map<String, dynamic> get allTask => {
        "pendingTask": _pendingTask
            .map((t) => {
                  'href': t.gallery.galleryurl!,
                  'name': t.gallery.dirName,
                  'gallery': t.gallery
                })
            .toList(),
        "runningTask": _runningTask.values
            .map((e) => {...e.toMap, 'gallery': e.gallery})
            .toList()
      };

  /// Handles messages for task management and updates.
  Future<bool> messageHandle(Message msg) async {
    var useHandle = await _runningTask.keys
        .firstWhereOrNull((e) => msg.id == e.gallery.id)
        ?.handle
        ?.call(msg);
    switch (msg) {
      case TaskStartMessage():
        {
          var target = msg.target;
          if (target is Gallery) {
            return illeagalTagsCheck(msg.gallery, config.excludes)
                ? _findUnCompleteGallery(msg.gallery, msg.file as Directory)
                    .catchError((e) {
                    logger?.e(e);
                    return true;
                  }, test: (error) => true).then((value) {
                    if (value) {
                      return helper
                          .updateTask(msg.gallery.id, msg.gallery.dirName,
                              msg.file.path, false)
                          .then((value) =>
                              helper.insertGallery(msg.gallery, msg.file));
                    }
                    return value;
                  })
                : false;
          }
          return true;
        }

      /// Handles the completion of a download task and updates the database accordingly.
      case DownLoadFinished():
        {
          if (msg.target is List) {
            if (msg.success) {
              await helper.removeTask(msg.id);
            } else {
              await helper.updateTask(
                  msg.gallery.id,
                  msg.gallery.dirName,
                  msg.file.path,
                  (msg.target as List<Image>).length /
                          msg.gallery.files.length >
                      0.1);
            }
            logger?.i('down finish ${msg.gallery}');
            if ((_runningTask.keys
                        .firstWhereOrNull((e) => msg.id == e.gallery.id)
                        ?.isCancelled ??
                    false) ==
                false) {
              return HitomiDir(msg.file as Directory, this, msg.gallery,
                      fixFromNet: false)
                  .fixGallery();
            }
          } else if (msg.target is Gallery) {
            logger?.w('illeagal gallery ${msg}');
            return await helper.removeTask(msg.id);
          } else if (msg.target is Image) {
            return helper.querySql(
                'select * from GalleryFile where gid=? and hash=?', [
              msg.gallery.id,
              (msg.target as Image).hash
            ]).then((value) async {
              bool needInsert = value.firstOrNull == null;
              int hashValue = value.firstOrNull?['fileHash'] ??
                  await computeImageHash(
                          [MultipartFile.fromFileSync((msg.file as File).path)],
                          config.aiTagPath.isEmpty)
                      .then((l) => l[0])
                      .catchError((e) {
                    logger?.e('image file ${msg.file.path} hash error $e ');
                    msg.file.deleteSync();
                    return 0;
                  }, test: (error) => true);
              if (msg.gallery.language != 'japanese' &&
                  msg.gallery.files.length -
                          msg.gallery.files
                              .indexWhere((f) => f.name == msg.target.name) <=
                      8 &&
                  manager.adHash.any(
                      (hash) => compareHashDistance(hash, hashValue) < 4)) {
                logger?.w('fount ad image ${msg.file.path}');
                msg.gallery.files.removeWhere((f) => f == msg.target);
                return msg.file.delete().then((_) => false);
              } else if (needInsert) {
                if (msg.target == msg.gallery.files.first) {
                  await autoTagImages(msg.file.path, feature: true)
                      .then((l) => l.firstOrNull)
                      .then((imageFeature) => helper.updateGalleryFeatureById(
                          msg.gallery.id, imageFeature!.data!))
                      .catchError((e) => true, test: (error) => true);
                }
                return helper.insertGalleryFile(
                    msg.gallery, msg.target, hashValue);
              }
              return needInsert;
            });
          }
        }
      case DownLoadingMessage():
        {
          var key = _runningTask.keys
              .firstWhereOrNull((element) => element.gallery.id == msg.id);
          if ((key != null)) {
            _runningTask[key] = msg;
            taskObserver({'id': msg.id, ...msg.toMap, 'type': 'update'});
          }
        }
      default:
        break;
    }
    return useHandle ?? true;
  }

  Future<List<int?>> computeImageHash(
      List<MultipartFile> paths, bool localHash) async {
    if (localHash) {
      return paths
          .asStream()
          .asyncMap((f) async => imageHash(await f.finalize().fold(<int>[],
              (acc, i) => acc..addAll(i)).then((l) => Uint8List.fromList(l))))
          .fold(<int?>[], (m, h) => m..add(h));
    } else {
      return manager.dio
          .post<Map<String, dynamic>>('${config.aiTagPath}/evaluate',
              data: FormData.fromMap({'process': 'image_hash', 'file': paths}))
          .then((m) {
        var data = m.data!;
        return paths.map((e) => data[e.filename]).map((i) {
          if (i is int) {
            return i;
          } else if (i is double) {
            return i.toInt();
          }
          return null;
        }).toList();
      });
    }
  }

  DownLoader(
      {required this.config,
      required this.api,
      required this.helper,
      required this.taskObserver,
      required this.manager}) {
    limit = DateTime.parse(config.dateLimit);
    filter = filterGalleryDefault;
    api.registerCallBack(messageHandle);
    logger = manager.logger;
  }

  bool filterGalleryDefault(Gallery gallery) {
    if (!illeagalTagsCheck(gallery, config.excludes)) {
      logger?.d('$gallery contains excluded tags');
      return false;
    }
    if (!(DateTime.parse(gallery.date).compareTo(limit) > 0 &&
        gallery.files.length >= 18)) {
      logger?.d('$gallery not match filter');
      return false;
    }
    return true;
  }

  /// Generates image tags using a deep learning model based on the provided file path.
  /// It supports both single images and directories containing multiple images.
  /// The function sends an HTTP POST request to the AI tagger API endpoint specified in [config.aiTagPath].
  /// If successful, it returns a list of `ImageTagFeature` objects parsed from the response data.
  Future<List<ImageTagFeature>> autoTagImages(String filePath,
      {int limit = 40, bool feature = false}) async {
    File file = File(filePath);
    if (file.existsSync()) {
      var files = <MultipartFile>[];
      if (file.statSync().type == FileSystemEntityType.directory) {
        logger?.d('taggger image from directory $filePath');
        Directory(filePath).listSync().fold(
            files,
            (acc, f) => acc
              ..add(MultipartFile.fromFileSync(
                f.path,
              )));
      } else {
        files.add(MultipartFile.fromFileSync(
          filePath,
        ));
      }
      final formData = FormData.fromMap({
        'file': files,
        "limit": limit,
        'threshold': 0.2,
        'process': feature ? 'feature' : 'tagger'
      });
      return manager.dio
          .post<List<dynamic>>('${config.aiTagPath}/evaluate',
              data: formData, options: Options(responseType: ResponseType.json))
          .then((resp) => resp.data!)
          .then((l) => l.map((t) => ImageTagFeature.fromJson(t)).toList())
          .catchError((e) => <ImageTagFeature>[], test: (error) => true);
    }
    return [];
  }

  /// Finds and completes an incomplete gallery by comparing it with existing galleries in the specified directory.
  /// It checks if a new directory contains an incomplete or duplicate gallery compared to the provided gallery.
  Future<bool> _findUnCompleteGallery(Gallery gallery, Directory newDir) async {
    var ids = await manager.checkExistsId([gallery.id]).catchError(
        (e) => <int>[],
        test: (e) => true);
    if (ids.isEmpty) {
      if (gallery.hasAuthor && gallery.files.length > 80) {
        return fetchGalleryHashByAuthor(gallery, helper).then((hashes) async {
          if (hashes.isNotEmpty) {
            var exists = await fetchGalleryHash(gallery, this,
                    adHashes: manager.adHash, fullHash: true)
                .then((v) => findDuplicateGalleryIds(
                    gallery: gallery,
                    helper: helper,
                    threshold: config.threshold,
                    fileHashs: v.value,
                    logger: logger,
                    allFileHash: hashes,
                    reserved: true))
                .then((ids) => Future.wait(ids.map((id) => helper
                    .queryGalleryById(id)
                    .catchError((e) => api.fetchGallery(id, usePrefence: false),
                        test: (error) => true))));
            logger?.i(
                '${gallery.id} found duplicate with ${exists.map((g) => g.id).toList()}');
            var chapterDown = chapter(gallery.name);
            if (chapterDown.isNotEmpty &&
                exists.length == 1 &&
                chapterContains(chapterDown, chapter(exists[0].name))) {
              logger?.w('exist ${exists[0]} chapter upgrade to $gallery');
              newDir.deleteSync(recursive: true);
              exists[0].createDir(config.output).renameSync(newDir.path);
              return true;
            }
            await exists
                .map((e) => HitomiDir(e.createDir(config.output), this, e,
                    fixFromNet: false))
                .asStream()
                .asyncMap((event) => event.deleteGallery(
                    reason:
                        'new collection ${gallery.id} contails exists gallery ${event.gallery.id}'))
                .length;
          }
          return true;
        });
      }
      return true;
    }
    return Future.wait(ids.map((id) => helper.queryGalleryById(id)))
        .then((list) {
      var exist =
          compareGallerWithOther(gallery, list, config.languages, logger);
      var r = exist.id == gallery.id;
      if (r) {
        if (exist.createDir(config.output).path != newDir.path) {
          newDir.deleteSync(recursive: true);
          exist.createDir(config.output).renameSync(newDir.path);
        } else {
          list
              .where((g) => g.id != gallery.id)
              .map((g) => HitomiDir(g.createDir(config.output), this, g))
              .forEach((h) => h.deleteGallery(reason: 'duplicate gallery'));
        }
      }
      return r;
    });
  }

  bool illeagalTagsCheck(Gallery gallery, List<FilterLabel> excludes) {
    final labels = gallery.labels();
    if (labels.isEmpty) {
      return true;
    }
    var illeagalTags =
        excludes.where((element) => labels.contains(element)).toList();
    if (illeagalTags.fold(0.0, (acc, i) => acc + i.weight) >= 1.0) {
      logger?.w('${gallery.id} found forbidden tag $illeagalTags');
      return false;
    }
    final checkResult =
        pow(10, illeagalTags.length) * 2 / gallery.files.length < 0.5;
    return checkResult;
  }

  Future<bool> _downLoadGallery(IdentifyToken token) async {
    var b = await api.downloadImages(token.gallery, token: token).catchError(
        (e) async {
      logger?.e('$token catch error $e');
      return false;
    }, test: (e) => true);
    _runningTask.remove(token);
    taskObserver(
        {'id': token.gallery.id, 'type': 'remove', 'target': 'running'});
    notifyTaskChange();
    return b;
  }

  Future<IdentifyToken> addTask(Gallery gallery,
      {Future<bool> Function(Message msg)? handle,
      bool immediately = true}) async {
    logger!.d('add task ${gallery.id}');
    var token = IdentifyToken(gallery);
    token.handle = handle;
    _pendingTask.add(token);
    taskObserver({
      'id': token.gallery.id,
      'type': 'add',
      'target': 'pending',
      'gallery': gallery
    });
    final path = join(config.output, gallery.dirName);
    await helper.updateTask(gallery.id, gallery.dirName, path, false);
    if (immediately) {
      notifyTaskChange(id: gallery.id);
    }
    return token;
  }

  /// Cancels a task by its ID.
  ///
  /// This method searches for the task with the given [id] in the running tasks list.
  /// If found, it cancels the task and waits until the task is completely removed from the running tasks list.
  /// It then updates the task status to reflect that the task has been cancelled.
  Future<bool> cancelById(int id) async {
    var target = _runningTask.keys
        .firstWhereOrNull((element) => element.gallery.id == id);
    if (target != null) {
      target.cancel('cancel');
      logger!.d('cancel task $id');
      while (_runningTask.containsKey(target)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      taskObserver({'id': id, 'type': 'remove', 'target': 'running'});
      addTask(target.gallery, immediately: false);
    }
    return target != null;
  }

  Future<bool> deleteById(int id) async {
    await cancelById(id); // 取消任务
    var target = _pendingTask
        .firstWhereOrNull((element) => element.gallery.id == id)
        ?.gallery; // 查找待处理的任务
    if (target != null) {
      _pendingTask.removeWhere((element) => element.gallery.id == id); // 移除任务
      taskObserver({'id': id, 'type': 'remove', 'target': 'pending'}); // 更新任务状态
    }
    if (target == null) {
      var path = await helper
          .readlData<String>('Gallery', 'path', {'id': id}); // 读取路径数据
      if (path != null) {
        target = await readGalleryFromPath(join(config.output, path), logger)
            .catchError((e) => api.fetchGallery(id, usePrefence: false),
                test: (error) => true); // 尝试从路径读取画廊
      }
    }
    if (target != null && target.id == id) {
      await HitomiDir(
              target.createDir(config.output, createDir: false), this, target)
          .deleteGallery(reason: 'user delete'); // 删除画廊
    }
    await helper.removeTask(id, withGaller: true); // 移除任务记录
    return target != null;
  }

  void cancelAll() async {
    _runningTask.forEach((element, value) async {
      await cancelById(element.gallery.id);
    });
  }

  /// Starts a task by moving the first pending task to the running list and notifying observers.
  Future<bool> notifyTaskChange({int? id}) async {
    if (_runningTask.length < min(5, config.maxTasks) &&
        _pendingTask.isNotEmpty) {
      IdentifyToken? token;
      if (id != null) {
        token = _pendingTask
            .firstWhereOrNull((element) => element.gallery.id == id);
      }
      token = token ?? _pendingTask.first;
      _pendingTask
          .removeWhere((element) => element.gallery.id == token!.gallery.id);
      taskObserver(
          {'id': token.gallery.id, 'type': 'remove', 'target': 'pending'});
      var msg = DownLoadingMessage(
          token.gallery, 0, 0, 0, token.gallery.files.length);
      _runningTask[token] = msg;
      taskObserver({
        'id': token.gallery.id,
        'type': 'add',
        'target': 'running',
        'gallery': token.gallery,
        ...msg.toMap
      });
      logger?.d(
          'run task ${token.gallery.id} left length ${_pendingTask.length} running ${_runningTask.length}');
      _downLoadGallery(token);
      return true;
    }
    logger?.i(
        'left task ${_pendingTask.length} running task ${_runningTask.length}');
    return false;
  }

  /// Fetches a list of galleries from the given IDs, filtering based on the provided condition function.
  /// The method queries the database for gallery paths and fetches them from the network if necessary,
  /// then filters the results based on the specified condition before returning the list of galleries.
  Future<List<Gallery>> _fetchGalleryFromIds(
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
                      ? await readGalleryFromPath(
                              join(config.output, path), logger)
                          .catchError((e) async {
                          var g = await fromNet;
                          logger?.e('read json $e from net $g');
                          File(join(
                                  g.createDir(config.output).path, 'meta.json'))
                              .writeAsStringSync(json.encode(g), flush: true);
                          return g;
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
                            max(0, config.languages.indexOf(pre.language!)) <=
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

  /// Fetches a list of galleries from the given IDs, filtering based on similar image hashes.
  /// The method queries for gallery paths and fetches them from the network if necessary,
  /// then filters out galleries that have similar images to previously fetched galleries.
  Future<List<Gallery>> _filterGalleryByImageHash(List<Gallery> list,
      CancelToken token, MapEntry<String, String>? entry) async {
    if (entry != null) {
      logger?.d(
          'fetching image hashes for label: ${entry.key} and value: ${entry.value}');
      var allHash = await helper.queryImageHashsByLabel(entry.key, entry.value);
      logger?.d('found ${allHash.keys} in db');
      list.sort((e1, e2) => e2.files.length - e1.files.length);
      return list
          .asStream()
          .asyncMap((event) => fetchGalleryHash(event, this,
                      adHashes: manager.adHash,
                      token: token,
                      fullHash: true,
                      outDir: config.output,
                      logger: logger)
                  .catchError((err) {
                logger?.e('fetchGalleryHash $err');
                return MapEntry(event, <int>[]);
              }, test: (error) => true))
          .where((event) => searchSimilerGaller(
                  MapEntry(event.key.id, event.value), allHash,
                  logger: logger, threshold: config.threshold)
              .isEmpty)
          .fold(<int, List<int>>{}, (previous, element) {
            var duplicate = searchSimilerGaller(
                MapEntry(element.key.id, element.value), previous,
                logger: logger, threshold: config.threshold);
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
            logger?.d(
                'scanning for duplicates with entry $entry: count ${previous.length}');
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
            logger?.e('error fetching galleries: $err');
            return <Gallery>[];
          }, test: (error) => true);
    } else {
      logger?.d('no entry provided for image hash filtering');
      return Future.value(list);
    }
  }

  /// Downloads galleries based on a list of tags and a filter condition, handling completion callbacks.
  /// The function takes a list of `Label` representing the tags, a map entry for image hashes, a cancel token,
  /// an optional callback for finishing the download process, and a where clause to filter galleries.
  Future<bool> downLoadByTag(
      List<Label> tags, MapEntry<String, String> entry, CancelToken token,
      {void Function(bool success)? onFinish,
      bool Function(Gallery gallery)? where}) async {
    if (where == null) {
      where = (Gallery gallery) =>
          filter(gallery) && (gallery.artists?.length ?? 0) <= 2;
    }
    final results = await fetchGallerysByTags(tags, where, token, entry)
        .then((value) async {
      logger?.d('useful result length ${value.length}');
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

  /// Fetches galleries based on a list of tags, an optional where clause to filter galleries, and a cancel token.
  /// The function takes a list of `Label` representing the tags, a bool function to filter galleries, a cancel token,
  /// and an optional map entry for image hashes.
  Future<List<Gallery>> fetchGallerysByTags(
      List<Label> tags,
      bool Function(Gallery gallery) where,
      CancelToken token,
      MapEntry<String, String>? entry) async {
    logger?.d('fetch tags ${tags}');
    return await api
        .search(tags, exclude: config.excludes)
        .then((value) => _fetchGalleryFromIds(value.data, where, token))
        .then((value) => _filterGalleryByImageHash(value, token, entry))
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
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! IdentifyToken) return false;
    return gallery.id == other.gallery.id;
  }
}
