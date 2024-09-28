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

  Stream<HitomiDir?> listDirs() {
    return Directory(_config.output)
        .list()
        .where((event) => event is Directory)
        .asyncMap((event) async {
      return readGalleryFromPath(event.path, _downLoader.logger)
          .then((value) async {
        if (!value.hasAuthor ||
            value.language != _downLoader.config.languages.first) {
          var newGallery = await _downLoader.api.fetchGallery(value.id);
          if (!value.hasAuthor && newGallery.hasAuthor ||
              newGallery.language != value.language) {
            var newDir = newGallery.createDir(_config.output);
            _downLoader.logger
                ?.d('fix ${value} label with path ${newDir.path} ');
            value = newGallery;
            File(path.join(newDir.path, 'meta.json'))
                .writeAsStringSync(json.encode(newGallery), flush: true);
            await _downLoader.helper.insertGallery(newGallery, newDir);
          }
        }
        final useDir = value.createDir(_config.output, createDir: false);
        if (!path
            .basename(useDir.path)
            .toLowerCase()
            .endsWith(path.basename(event.path).toLowerCase())) {
          if (useDir.existsSync() &&
              useDir.listSync().length - 1 >= value.files.length) {
            _downLoader.logger?.w(
                'delete ${value.id} path ${event.path} because exists $value');
            event.deleteSync(recursive: true);
            return null;
          } else {
            _downLoader.logger?.d(
                'rename ${value.id} path ${event.path} from ${path.basename(event.path)} to ${path.basename(useDir.path)}');
            await useDir
                .delete(recursive: true)
                .then((_) => event.rename(useDir.path))
                .then((_) => _downLoader.helper.insertGallery(value, useDir));
          }
          return HitomiDir(useDir, _downLoader, value);
        } else {
          return HitomiDir(event as Directory, _downLoader, value);
        }
      }).catchError((e) {
        var dir = event as Directory;
        _downLoader.logger?.e('$event error $e');
        // if (dir.listSync().isEmpty) {
        //   return HitomiDir(dir, _downLoader, null, manager);
        // }
        return _parseFromDir(event.path).then((value) async {
          if (value == null) {
            _downLoader.logger?.e('delete empty directory ${event.path}');
            await event
                .delete(recursive: true)
                .then((r) => null)
                .catchError((e) => null, test: (error) => true);
            return null;
          }
          return HitomiDir(dir, _downLoader, value);
        });
      }, test: (error) => true);
    });
  }

  Future<Map<bool, int>> fixMissDbRow() {
    return _helper
        .querySqlByCursor('select path,id,feature is null as feat from Gallery')
        .then((value) => value.asyncMap((event) {
              var id = event['id'];
              var dir = Directory(
                  path.join(_downLoader.config.output, event['path']));
              return readGalleryFromPath(dir.path, _downLoader.logger)
                  .then((value) async {
                if (value.id.toString() != id.toString()) {
                  _downLoader.logger?.i('db id $id found id ${value.id}');
                  return await _helper.deleteGallery(id);
                }
                if (event['feat'] == 1) {
                  await HitomiDir(dir, _downLoader, value)
                      .batchInsertImage([value.files.first], true);
                }
                return true;
              }).catchError((e) {
                _downLoader.logger?.e(' fix row $event error $e');
                return _downLoader.api
                    .fetchGallery(id, usePrefence: false)
                    .then((value) => _downLoader.filter(value)
                        ? _downLoader.addTask(value)
                        : false)
                    .then((value) => _helper.deleteGallery(id))
                    .catchError((e) async {
                  await _helper.deleteGallery(id);
                  return false;
                }, test: (error) => true);
              }, test: (error) => true);
            }).fold(
                <bool, int>{},
                (previous, element) =>
                    previous..[element] = (previous[element] ?? 0) + 1));
  }

  Future<int> removeDupGallery() async {
    return _helper
        .querySqlByCursor(
            'select distinct(ja.value) as author from Gallery g,json_each(g.artist) ja where json_valid(g.artist)=1')
        .then((value) => value
            .asyncMap((event) => _findDupByLaber('artist', event['author']))
            .where((event) => event.isNotEmpty)
            .asyncMap((event) => _collectionFromMap(event))
            .expand((element) => element.entries)
            .asyncMap((event) => event.key.compareWithOther(event.value))
            .length);
  }

  Future<Map<int, List<int>>> _findDupByLaber(String type, String name) async {
    return _helper
        .queryImageHashsByLabel(type, name)
        .then((value) => value.entries.fold(
            <int, List<int>>{},
            (previousValue, element) => previousValue
              ..[element.key] = searchSimilerGaller(element, value,
                  logger: _downLoader.logger)))
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
          _downLoader.logger
              ?.d('${gallery} match $name ${name.contains(gallery.dirName)}');
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
      return await completer.future.then((value) {
        _downLoader.logger?.d(
            '${gallery.id} lost ${fileLost.map((e) => path.basename(e.path)).toList()} redownload $value');
        return value;
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
                _downLoader.adImage.any((entry) =>
                    compareHashDistance(entry.key, img.fileHash ?? 0) < 3))
        .asStream()
        .asyncMap((img) {
      _downLoader.logger?.w(' ${gallery.id} remove db illegal file ${img}');
      gallery.files.removeWhere((s) => s == img);
      return _downLoader.helper.deleteGalleryFile(gallery.id, img.hash);
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

  Future<bool> compareWithOther(List<HitomiDir> others) async {
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
    if (left.id == this.gallery.id) {
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
        .then((value) => true)
        .catchError((e) {
      _downLoader.logger?.e('del gallery faild $e');
      return false;
    }, test: (error) => true);
  }

  Future<bool> batchInsertImage(Iterable<Image> images, bool generateTag) {
    return images
        .slices(3)
        .asStream()
        .asyncMap((imgs) => Future.wait(imgs.map((img) =>
            imageFileHash(File(path.join(dir.path, img.name))).catchError((e) {
              File(path.join(dir.path, img.name)).deleteSync();
              throw e;
            }, test: (error) => true).then((hash) async {
              var feature = img == gallery.files.first;
              var imageFeature = generateTag
                  ? await _downLoader
                      .autoTagImages(path.join(dir.path, img.name),
                          feature: feature)
                      .then((r) => r.firstOrNull)
                  : null;
              if (feature && imageFeature != null) {
                _downLoader.logger?.d('ganerate feature for ${gallery.id}');
                await _downLoader.helper
                    .updateGalleryFeatureById(gallery.id, imageFeature.data!);
              }
              return _downLoader.helper.insertGalleryFile(gallery, img, hash);
            }))).then((l) => l.fold(true, (acc, i) => acc && i)))
        .fold(true, (acc, i) => acc && i);
  }

  Future<bool> fixGallery() async {
    if (!_downLoader.filter(gallery)) {
      return deleteGallery(reason: 'filter failed');
    }
    var images = await _downLoader.helper.getImageListByGid(gallery.id);
    return _removeIllegalFiles(images)
        .then((value) => _tryFixMissingFile())
        .then((value) => _downLoader.helper.querySql(
            'select feature,title from Gallery where id=? and length!=0',
            [gallery.id]))
        .then((set) async {
      if (set.firstOrNull == null ||
          set.firstOrNull?['title'] != gallery.name) {
        await _downLoader.helper.insertGallery(gallery, dir);
      }
      if (set.firstOrNull?['feature'] == null) {
        await batchInsertImage([gallery.files.first], true);
      }
      var missing = gallery.files
          .where((f) => images.every((i) => i.hash != f.hash))
          .toList();
      var lost = missing.isEmpty;
      if (missing.isNotEmpty) {
        _downLoader.logger?.d(
            '${gallery} fix file missing ${missing.map((e) => e.name).toList()}');
        lost = await batchInsertImage(missing, false);
      }
      // missing = _downLoader.config.aiTagPath.isNotEmpty
      //     ? value
      //         .where((e) =>
      //             missing.every((miss) => miss.hash != e.key[1]) &&
      //             e.value.firstOrNull?['tag'] == 1)
      //         .map((element) => gallery.files
      //             .firstWhere((e) => e.hash == element.key[1]))
      //         .where((e) => File(path.join(dir.path, e.name)).existsSync())
      //         .toList()
      //     : [];
      // if (missing.isNotEmpty) {
      //   _downLoader.logger?.d(
      //       '${gallery} fix tag missing ${missing.map((e) => e.name).toList()}');
      //   lost = await batchInsertImage(missing, true);
      // }
      return lost;
    }).catchError((e, stack) {
      _downLoader.logger?.e('scan gallery faild $e $stack');
      return false;
    }, test: (error) => true);
  }
}
