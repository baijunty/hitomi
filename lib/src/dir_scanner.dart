import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/downloader.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/common.dart';

import '../gallery/gallery.dart';
import '../gallery/language.dart';
import 'gallery_util.dart';

class DirScanner {
  final UserConfig _config;
  final SqliteHelper _helper;
  final DownLoader _downLoader;
  final IsolateManager<List<int>?, String> manager;
  static final titleReg = RegExp(r'\((.+)\)(.+)');
  DirScanner(this._config, this._helper, this._downLoader, this.manager);

  Stream<HitomiDir> listDirs() {
    final stream = StreamController<HitomiDir>();
    Directory(_config.output)
        .list()
        .filterInstance<Directory>()
        .asyncMap((d) => readGalleryFromPath(d.path, _downLoader.logger)
                .then((v) => stream.add(HitomiDir(d, _downLoader, v)))
                .catchError((e) async {
              _downLoader.logger?.e('read ${d.path} error');
              return _parseFromDir(d.path).then((value) {
                if (value == null) {
                  _downLoader.logger
                      ?.w('delete ${d.path} because has no metadata');
                  d.deleteSync(recursive: true);
                  return;
                }
                stream.add(HitomiDir(d, _downLoader, value));
              });
            }, test: (error) => true))
        .length
        .then((l) => _helper
            .querySqlByCursor('select path,id from Gallery')
            .then((value) => value.asyncMap((row) async {
                  final id = row['id'];
                  var dir = Directory(
                      path.join(_downLoader.config.output, row['path']));
                  try {
                    if (!dir.existsSync()) {
                      var v = await _downLoader.api
                          .fetchGallery(id, usePrefence: false);
                      dir = v.createDir(_downLoader.config.output);
                      if (dir.listSync().isEmpty) {
                        _downLoader.logger
                            ?.d('fix gallery ${id} with ${dir.path}');
                        File(path.join(dir.path, 'meta.json'))
                            .writeAsStringSync(json.encode(v), flush: true);
                        stream.add(HitomiDir(dir, _downLoader, v));
                      } else {
                        _downLoader.logger
                            ?.d('update gallery ${id} new dir ${dir.path}');
                        await _helper.insertGallery(v, dir);
                      }
                    } else {
                      var v = await readGalleryFromPath(
                          dir.path, _downLoader.logger);
                      if (v.id != id) {
                        _downLoader.logger
                            ?.d('delete gallery ${id} exits  ${dir.path}');
                        await _helper.deleteGallery(id);
                      }
                    }
                  } catch (e) {
                    _downLoader.logger
                        ?.e('fetch gallery $id path ${dir.path}  error $e');
                  }
                }).length))
        .whenComplete(() => stream.close())
        .catchError((e) {
      _downLoader.logger?.e('list dirs error $e');
      stream.addError(e);
      stream.close();
      return 0;
    }, test: (e) => true);
    return stream.stream;
  }

  Future<int> removeDupGallery() async {
    var cursor = await _helper.querySqlByCursor(
        "select t.name,t.type from GalleryTagRelation r left join Tags t on r.tid = t.id where t.type='artist' or t.type='group' group by t.name having count(t.name)>1");
    return cursor
        .asyncMap((event) => _findDupByLaber(event['type'], event['name']))
        .where((event) => event.isNotEmpty)
        .asyncMap((event) => _collectionFromMap(event))
        .expand((element) => element.entries)
        .asyncMap((event) => event.key._compareThenDel(event.value))
        .length;
  }

  Future<Map<int, List<int>>> _findDupByLaber(String type, String name) async {
    return _helper
        .queryImageHashsByLabel(type, name)
        .then((value) => value.entries.fold(
            <int, List<int>>{},
            (previousValue, element) => previousValue
              ..[element.key] = searchSimilerGaller(element, value,
                  logger: _downLoader.logger,
                  threshold: _downLoader.config.threshold)))
        .then((value) => value..removeWhere((key, value) => value.isEmpty));
  }

  Future<Map<HitomiDir, List<HitomiDir>>> _collectionFromMap(
      Map<int, List<int>> map) async {
    final ids = map.entries.fold(<int>{}, (previousValue, element) {
      previousValue.add(element.key);
      previousValue.addAll(element.value);
      return previousValue;
    });
    final rowMaps = await _helper
        .selectSqlMultiResultAsync(
            'select * from Gallery where id=?', ids.map((e) => [e]).toList())
        .then((value) => ids.fold(
            <int, Row>{},
            (previousValue, element) => previousValue
              ..[element] = value.entries
                  .firstWhere((entry) => entry.key.first == element)
                  .value
                  .first));
    final idMap = await rowMaps.entries
        .asStream()
        .map((event) => MapEntry(event.key,
            Directory(path.join(_config.output, event.value['path']))))
        .where((event) => event.value.existsSync())
        .asyncMap((event) async {
      return readGalleryFromPath(event.value.path, _downLoader.logger)
          .then((value) => HitomiDir(event.value, _downLoader, value))
          .then((value) => MapEntry(event.key, value));
    }).fold(<int, HitomiDir>{},
            (previous, element) => previous..[element.key] = element.value);
    return map.map((key, value) => MapEntry(
        idMap[key]!,
        value.fold(<HitomiDir>[],
            (previousValue, element) => previousValue..add(idMap[element]!))));
  }

  Future<Gallery?> _parseFromDir(String dir) async {
    final name = path.basename(dir);
    final match = titleReg.firstMatch(name);
    final tags = <Label>[];
    MapEntry<String, String>? entry = null;
    var id = await _helper.querySql('select id from Gallery where path = ?',
        [dir]).then((value) => value.firstOrNull?['path']);
    if (id != null) {
      _downLoader.logger?.e('fix by id $id');
      return _downLoader.api.fetchGallery(id);
    } else if (match != null && match.groupCount == 2) {
      var artist = match.group(1)!;
      var title = match.group(2)!;
      entry = MapEntry('artist', artist);
      tags.addAll([
        Artist(artist: artist),
        ...title.split(blankExp).take(5).map((e) => QueryText(e)).toSet()
      ]);
    } else {
      tags.addAll(name.split(blankExp).map((e) => QueryText(e)).toSet());
    }
    _downLoader.logger?.e('fix by search $tags');
    return _downLoader
        .fetchGallerysByTags([
          ...tags,
          ..._config.languages.map((e) => Language(name: e)),
          TypeLabel('doujinshi'),
          TypeLabel('manga')
        ], (Gallery gallery) {
          _downLoader.logger?.d(
              '${gallery.name} match $name ${name.contains(gallery.dirName)}');
          return name.contains(gallery.dirName);
        }, CancelToken(), entry)
        .then((value) =>
            value.firstWhereOrNull(
                (element) => element.language == _config.languages.first) ??
            value.firstOrNull)
        .then((value) {
          if (value != null) {
            _downLoader.logger?.i('fix meta json ${value.name}');
            File(path.join(dir, 'meta.json')).writeAsString(json.encode(value));
            return value;
          }
          return null;
        });
  }
}

class HitomiDir {
  final Directory dir;
  final Gallery gallery;
  final DownLoader _downLoader;
  final bool fixFromNet;
  HitomiDir(this.dir, this._downLoader, this.gallery, {this.fixFromNet = true});

  bool get needDownMissFile =>
      _downLoader.filter(gallery) &&
      fixFromNet &&
      gallery.files
          .map((e) => File(path.join(dir.path, e.name)))
          .any((element) => !element.existsSync() || element.lengthSync() == 0);

  Future<bool> _tryFixMissingFile() async {
    var fileLost = gallery.files
        .map((e) => File(path.join(dir.path, e.name)))
        .where((element) => !element.existsSync() || element.lengthSync() == 0)
        .toList();
    if (fileLost.isNotEmpty && fixFromNet) {
      var completer = Completer<bool>();
      await _downLoader.addTask(gallery, handle: (msg) async {
        if (msg is DownLoadFinished) {
          if (msg.target is List) {
            _downLoader.logger?.d('redown ${msg.success}');
            completer.complete(msg.success);
          } else if (msg.target is Gallery) {
            _downLoader.logger?.d('redown faild');
            completer.complete(false);
          }
        }
        return true;
      });
      return await completer.future.then((value) async {
        if (value) {
          _downLoader.logger?.i(
              '${gallery.id} lost ${fileLost.map((e) => path.basename(e.path)).toList()} redownload $value');
        } else {
          try {
            await _downLoader.api.fetchGallery(gallery.id, usePrefence: false);
          } catch (_) {
            if (gallery.files
                        .map((e) => File(path.join(dir.path, e.name)))
                        .where((element) =>
                            !element.existsSync() || element.lengthSync() == 0)
                        .length /
                    gallery.files.length >=
                0.5) {
              await deleteGallery(
                  reason: 'lost too many files and original fetch failed');
              return false;
            }
          }
        }
        return true;
      });
    }
    return true;
  }

  Future<bool> _removeIllegalFiles(List<Image> dbImages) async {
    final len = dbImages.length;
    await dbImages
        .whereIndexed((index, img) =>
            !gallery.files.any((f) => f == img) ||
            (len - index) < 8 &&
                _downLoader.manager.adHash.any((entry) =>
                    compareHashDistance(entry, img.fileHash ?? 0) < 3))
        .asStream()
        .asyncMap((img) {
      _downLoader.logger?.w(' ${gallery.id} remove db illegal file ${img}');
      gallery.files.removeWhere((s) => s == img);
      return _downLoader.helper.deleteGalleryFile(gallery.id, img.name);
    }).fold(true, (pre, r) => pre && r);
    if (len != dbImages.length) {
      File(path.join(dir.path, 'meta.json'))
          .writeAsStringSync(json.encode(gallery), flush: true);
    }
    return dir
        .list()
        .map((e) => path.basename(e.path))
        .takeWhile(
            (element) => imageExtension.contains(path.extension(element)))
        .where((element) => !gallery.files.any((f) => f.name.endsWith(element)))
        .fold(<String>[], (previous, element) => previous..add(element)).then(
            (value) async {
      if ((value.isNotEmpty)) {
        _downLoader.logger?.w('del ${dir.path} files ${value} from ${gallery}');
        await Future.wait(value.map(
            (img) => _downLoader.helper.deleteGalleryFile(gallery.id, img)));
        value.map((e) => File(path.join(dir.path, e))).forEach((element) {
          element.deleteSync();
        });
      }
      return true;
    }).catchError((e) {
      _downLoader.logger?.e('fix images err with $e');
      return false;
    }, test: (error) => true);
  }

  Future<bool> _compareThenDel(List<HitomiDir> others) async {
    var left = compareGallerWithOther(
        this.gallery,
        others
            .map((e) => e.gallery)
            .where((e) => e
                .createDir(_downLoader.config.output, createDir: false)
                .existsSync())
            .toList(),
        _downLoader.config.languages,
        _downLoader.logger);
    if (left.id == this.gallery.id && dir.existsSync()) {
      return others
          .asStream()
          .asyncMap((event) =>
              event.deleteGallery(reason: 'compare exists ${left.id}'))
          .fold(true, (previous, element) => previous && element);
    } else {
      return deleteGallery(reason: 'exist better ${left.id}');
    }
  }

  Future<bool> deleteGallery({String reason = ''}) async {
    _downLoader.logger?.w(
        'because $reason del gallery $gallery with path $dir exists ${dir.existsSync()}');
    return _downLoader.helper
        .deleteGallery(gallery.id)
        .then((value) => dir.exists())
        .then((value) => value ? dir.delete(recursive: true) : false)
        .then((value) {
      if (gallery.hasAuthor) {
        _downLoader.manager.countChange(
            [...gallery.artists ?? [], ...gallery.groups ?? []], -1);
      }
      return true;
    }).catchError((e) {
      _downLoader.logger?.e('del gallery $gallery faild');
      return false;
    }, test: (error) => true);
  }

  Future<bool> batchInsertImage(Iterable<Image> images) {
    final files = images
        .map((img) => File(path.join(dir.path, img.name)))
        .where((f) => f.existsSync());
    return _downLoader
        .computeImageHash(
            files.map((f) => MultipartFile.fromFileSync(f.path)).toList(),
            _downLoader.config.aiTagPath.isEmpty)
        .catchError(
            (e) => files
                .asStream()
                .asyncMap((f) => _downLoader.computeImageHash(
                        [MultipartFile.fromFileSync(f.path)],
                        true).catchError((e) {
                      _downLoader.logger?.i('compute $f hash err');
                      f.deleteSync();
                      return [null];
                    }, test: (e) => true))
                .fold(
                    <int?>[], (previous, element) => previous..addAll(element)),
            test: (error) => true)
        .then((hashList) async {
          return Future.wait(files
              .mapIndexed((index, f) => MapEntry(
                  images.firstWhere((img) => img.name == path.basename(f.path)),
                  hashList[index]))
              .where((e) => e.value != null)
              .map((e) => _downLoader.helper
                  .insertGalleryFile(gallery, e.key, e.value)));
        })
        .then((r) => r.fold(true, (acc, i) => acc && i))
        .then((v) => v);
  }

  Future<bool> generateFuture() async {
    var f = await _downLoader
        .autoTagImages(path.join(dir.path, gallery.files.first.name),
            feature: true)
        .then((r) => r.firstOrNull);
    if (f != null) {
      _downLoader.logger?.d('ganerate feature for ${gallery.id}');
      return await _downLoader.helper
          .updateGalleryFeatureById(gallery.id, f.data!);
    }
    return false;
  }

  Future<bool> fixGallery() async {
    if (!_downLoader.filter(gallery)) {
      return deleteGallery(reason: 'filter failed');
    }
    var images = await _downLoader.helper.getImageListByGid(gallery.id);
    return _removeIllegalFiles(images)
        .then((value) => _tryFixMissingFile())
        .then((value) async {
      if (value) {
        return _downLoader.helper.querySql(
            'select feature,title,date from Gallery where id=?',
            [gallery.id]).then((set) async {
          if (set.firstOrNull == null ||
              set.firstOrNull?['title'] != gallery.name ||
              set.firstOrNull?['date'] == 0) {
            await _downLoader.helper.insertGallery(gallery, dir);
          }
          if (set.firstOrNull?['feature'] == null) {
            await generateFuture();
          }
          var missing = gallery.files
              .where((f) =>
                  File(path.join(dir.path, f.name)).existsSync() &&
                  images.every((i) => i.name != f.name))
              .toList();
          var lost = missing.isEmpty;
          if (missing.isNotEmpty) {
            _downLoader.logger?.i(
                '${gallery.dirName} fix file missing ${missing.map((e) => e.name).toList()}');
            lost = await batchInsertImage(missing);
          }
          return lost;
        });
      }
      return value;
    }).catchError((e) {
      _downLoader.logger?.e('scan gallery faild');
      return false;
    }, test: (error) => true);
  }
}
