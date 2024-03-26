import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/downloader.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/common.dart';

import '../gallery/gallery.dart';
import '../gallery/language.dart';
import 'gallery_util.dart';
import 'sqlite_helper.dart';

class DirScanner {
  final UserConfig _config;
  final SqliteHelper _helper;
  final DownLoader _downLoader;
  final IsolateManager<MapEntry<int, List<int>?>, String> manager;
  static final titleReg = RegExp(r'\((.+)\)(.+)');
  DirScanner(this._config, this._helper, this._downLoader, this.manager);

  Stream<HitomiDir?> listDirs() {
    return Directory(_config.output)
        .list()
        .where((event) => event is Directory)
        .asyncMap((event) async {
      return readGalleryFromPath(event.path).then((value) async {
        final useDir = value.createDir(_config.output);
        if (!path
            .basename(useDir.path)
            .toLowerCase()
            .endsWith(path.basename(event.path).toLowerCase())) {
          print(
              'rename ${value.id} path ${event.path} from ${path.basename(event.path)} to ${path.basename(useDir.path)}');
          return await useDir
              .delete(recursive: true)
              .then((v) => event.rename(v.path))
              .then(
                  (v) => HitomiDir(v as Directory, _downLoader, value, manager))
              .catchError((e) {
            _downLoader.logger?.e(e);
            return HitomiDir(
                value.createDir(_config.output), _downLoader, value, manager);
          }, test: (error) => true);
        }
        return HitomiDir(event as Directory, _downLoader, value, manager);
      }).catchError((e) {
        _downLoader.logger?.e('$event error $e');
        var dir = event as Directory;
        // if (dir.listSync().isEmpty) {
        //   return HitomiDir(dir, _downLoader, null, manager);
        // }
        return _parseFromDir(event.path)
            .then((value) => HitomiDir(dir, _downLoader, value, manager));
      }, test: (error) => true);
    });
  }

  Future<Map<bool, int>> fixMissDbRow() {
    return _helper
        .querySqlByCursor('select path,id from Gallery')
        .asyncMap((event) {
      var id = event['id'];
      var dir = Directory(path.join(_downLoader.config.output, event['path']));
      return readGalleryFromPath(dir.path).then((value) async {
        await HitomiDir(dir, _downLoader, value, manager).fixGallery();
        if (value.id.toString() != id.toString()) {
          _downLoader.logger?.i('db id $id found id ${value.id}');
          return await _helper.deleteGallery(id);
        }
        return true;
      }).catchError(
          (e) => _downLoader.api
              .fetchGallery(id, usePrefence: false)
              .then((value) => _downLoader.addTask(value))
              .then((value) => _helper.deleteGallery(id))
              .catchError((e) => false, test: (error) => true),
          test: (error) => true);
    }).fold(
            <bool, int>{},
            (previous, element) =>
                previous..[element] = (previous[element] ?? 0) + 1);
  }

  Future<int> removeDupGallery() async {
    return _helper
        .querySqlByCursor(
            'select distinct(ja.value) as author from Gallery g,json_each(g.artist) ja where json_valid(g.artist)=1')
        .asyncMap((event) => _findDupByLaber('artist', event['author']))
        .where((event) => event.isNotEmpty)
        .asyncMap((event) => _collectionFromMap(event))
        .expand((element) => element.entries)
        .asyncMap((event) => event.key.compareWithOther(event.value))
        .length;
  }

  Future<Map<int, List<int>>> _findDupByLaber(String type, String name) async {
    var r = _helper
        .queryImageHashsByLabel(type, name)
        .then((value) => value.entries.fold(
            <int, List<int>>{},
            (previousValue, element) => previousValue
              ..[element.key] = searchSimilerGaller(element, value,
                  logger: _downLoader.logger)))
        .then((value) => value..removeWhere((key, value) => value.isEmpty));
    return r;
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
      return readGalleryFromPath(event.value.path)
          .then((value) => HitomiDir(event.value, _downLoader, value, manager))
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
        ...title.split(blankExp).take(5).map((e) => QueryText(e))
      ]);
    } else {
      tags.addAll(name.split(blankExp).map((e) => QueryText(e)));
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
  final Gallery? gallery;
  final DownLoader _downLoader;
  final IsolateManager<MapEntry<int, List<int>?>, String> manager;
  final bool fixFromNet;
  HitomiDir(this.dir, this._downLoader, this.gallery, this.manager,
      {this.fixFromNet = true});

  Future<int> get coverHash => File('${dir.path}/${gallery?.files.first.name}')
      .readAsBytes()
      .then((value) => imageHash(value));

  Future<bool> _fixIllegalFiles() async {
    if (gallery != null) {
      var files = gallery!.files.map((e) => e.name).toList();
      var fileLost = files
          .map((e) => File(path.join(dir.path, e)))
          .where((element) => !element.existsSync())
          .toList();
      if (fileLost.isNotEmpty && fixFromNet) {
        var token = CancelToken();
        var result =
            await _downLoader.api.downloadImages(gallery!, token: token);
        _downLoader.logger
            ?.d('${gallery!.id} lost ${fileLost} redownload $result');
      }
      await dir
          .list()
          .map((e) => path.basename(e.path))
          .takeWhile(
              (element) => imageExtension.contains(path.extension(element)))
          .where((element) => !files.any((f) => f.endsWith(element)))
          .fold(<String>[], (previous, element) => previous..add(element)).then(
              (value) async {
        if ((value.isNotEmpty)) {
          _downLoader.logger?.w('del ${dir.path} files ${value} from ${files}');
          value.map((e) => File(path.join(dir.path, e))).forEach((element) {
            element.deleteSync();
          });
          // return _downLoader.helper.excuteSqlMultiParams(
          //     'delete from GalleryFile where gid =? and name=?',
          //     value.map((e) => [gallery!.id, e]).toList());
        }
        return true;
      });
    }
    return false;
  }

  Future<bool> compareWithOther(List<HitomiDir> others) async {
    var left = compareGallerWithOther(
        this.gallery!,
        others.map((e) => e.gallery!).toList(),
        _downLoader.config.languages,
        _downLoader.logger);
    if (left.id == this.gallery!.id) {
      return others
          .asStream()
          .asyncMap((event) => event.deleteGallery())
          .fold(true, (previous, element) => previous && element);
    } else {
      return deleteGallery();
    }
  }

  Future<bool> deleteGallery() async {
    _downLoader.logger?.w('del gallery $gallery with path $dir');
    return _downLoader.helper
        .deleteGallery(gallery!.id)
        .then((value) => dir.exists())
        .then((value) => value ? dir.delete(recursive: true) : false)
        .then((value) => true)
        .catchError((e) {
      _downLoader.logger?.e('del gallery faild $e');
      return false;
    }, test: (error) => true);
  }

  Future<bool> fixGallery() async {
    if (gallery != null) {
      if (!_downLoader.illeagalTagsCheck(
              gallery!, _downLoader.config.excludes) ||
          (gallery!.files.length) < 18) {
        return deleteGallery();
      }
      return _fixIllegalFiles()
          // .then((value) => _downLoader.helper.insertGallery(gallery!, dir.path))
          .then((value) => _downLoader.helper.querySql(
              'select 1 from Gallery where id=? and length!=0', [gallery!.id]))
          .then((value) => value.firstOrNull == null
              ? _downLoader.helper.insertGallery(gallery!, dir.path)
              : true)
          .then((_) {
        return _downLoader.helper
            .selectSqlMultiResultAsync(
                'select 1 from GalleryFile where gid=? and hash=?',
                gallery!.files.map((e) => [gallery!.id, e.hash]).toList())
            .then((value) => value.entries
                .where((element) => element.value.firstOrNull == null))
            .then((value) => value.map((e) => e.key))
            .then((value) => value.toList())
            .then((value) {
          final fs = value
              .map((element) =>
                  gallery!.files.firstWhere((e) => e.hash == element[1]))
              .toList();
          if (fs.isEmpty) {
            return Future.value(true);
          }
          var time = DateTime.now();
          return Future.wait(fs
                  .map((img) => manager.compute(path.join(dir.path, img.name))))
              .then((value) {
            _downLoader.logger?.d(
                '${gallery!.id} lost ${value.length} compute time ${DateTime.now().difference(time).inSeconds} ');
            return Future.wait(value.mapIndexed((index, value) =>
                _downLoader.helper.insertGalleryFile(gallery!, fs[index],
                    value.key, value.value))).then((value) => value.fold(
                true, (previousValue, element) => previousValue && element));
          });
        });
      }).catchError((e) async {
        _downLoader.logger?.e('scan gallery faild $e');
        await deleteGallery();
        return false;
      }, test: (error) => true);
    } else {
      _downLoader.logger?.w('delete directory ${dir.path}');
      return dir.delete(recursive: true).then((value) => true).catchError((e) {
        _downLoader.logger?.e('delete directory faild $e');
        return false;
      }, test: (error) => true);
    }
  }
}
