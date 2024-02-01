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

import '../gallery/gallery.dart';
import '../gallery/language.dart';
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
      return File('${event.path}/meta.json')
          .readAsString()
          .then((value) => HitomiDir(event as Directory, _downLoader,
              Gallery.fromJson(value), manager))
          .catchError((e) {
        _downLoader.logger?.e('$event error $e');
        return _parseFromDir(event.path).then((value) =>
            HitomiDir(event as Directory, _downLoader, value, manager));
      }, test: (error) => true);
    });
  }

  Future<Map<bool, int>> fixMissDbRow() {
    CursorImpl? cursor;
    return _helper
        .querySqlByCursor('select path,id from Gallery')
        .asStream()
        .expand((element) {
      cursor = element;
      return element;
    }).asyncMap((event) {
      var dir = Directory(path.join(_downLoader.config.output, event['path']));
      var meta = File(path.join(dir.path, 'meta.json'));
      var id = event['id'];
      _downLoader.logger?.d('fix line $id ${meta.path} ${meta.existsSync()}');
      if (dir.existsSync() && meta.existsSync()) {
        return meta
            .readAsString()
            .then((value) => Gallery.fromJson(value))
            .then((value) async {
          HitomiDir(dir, _downLoader, value, manager).fixGallery();
          if (value.id.toInt() != id.toInt()) {
            return await _helper.deleteGallery(id);
          }
          return true;
        }).catchError((e) => false, test: (error) => true);
      } else {
        return _downLoader.api
            .fetchGallery(id, usePrefence: false)
            .then((value) => _downLoader.addTask(value))
            .then((value) => _helper.deleteGallery(id))
            .catchError((e) => false, test: (error) => true);
      }
    }).fold(
            <bool, int>{},
            (previous, element) => previous
              ..[element] = (previous[element] ?? 0) + 1).whenComplete(
            () => cursor?.dispose());
  }

  Future<Gallery?> _parseFromDir(String dir) async {
    final name = path.basename(dir);
    final match = titleReg.firstMatch(name);
    final tags = <Lable>[];
    var id = await _helper.querySql('select id from Gallery where path = ?',
        [dir]).then((value) => value.firstOrNull?['path']);
    if (id != null) {
      _downLoader.logger?.e('fix by id $id');
      return _downLoader.api.fetchGallery(id);
    } else if (match != null && match.groupCount == 2) {
      var artist = match.group(1)!;
      var title = match.group(2)!;
      tags.addAll([
        Artist(artist: artist),
        ...title.split(blankExp).map((e) => QueryText(e))
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
        }, CancelToken())
        .then((value) =>
            value.firstWhereOrNull(
                (element) => element.language == _config.languages.first) ??
            value.first)
        .then((value) {
          _downLoader.logger?.i('fix meta json ${value.name}');
          File(dir + '/' + 'meta.json').writeAsString(json.encode(value));
          return value;
        });
  }
}

class HitomiDir {
  final Directory dir;
  final Gallery? gallery;
  final DownLoader _downLoader;
  final IsolateManager<MapEntry<int, List<int>?>, String> manager;
  HitomiDir(this.dir, this._downLoader, this.gallery, this.manager);

  bool get dismatchFile => gallery?.files.length != dir.listSync().length - 1;

  Future<int> get coverHash => File('${dir.path}/${gallery?.files.first.name}')
      .readAsBytes()
      .then((value) => imageHash(value));

  bool _removeIllegalFile() {
    if (dismatchFile && gallery != null) {
      var files = gallery!.files.map((e) => e.name).toList();
      dir
          .listSync()
          .whereNot((element) =>
              files.contains(path.basename(element.path)) ||
              path.extension(element.path) == '.json')
          .forEach((element) {
        try {
          _downLoader.logger?.w('del file ${element.path}');
          element.deleteSync();
        } catch (e) {
          _downLoader.logger?.e('del failed $e');
        }
      });
    }
    return dismatchFile;
  }

  bool get tagIlleagal {
    return gallery != null
        ? _downLoader.containsIlleagalTags(
            gallery!, _downLoader.config.excludes)
        : false;
  }

  Future<String> callPythonProcess(String path) async {
    return Process.run('/home/bai/venv/bin/python3.11', [
      'test/encode.py',
      path
    ]).then((value) => value.exitCode == 0 ? value.stdout : throw value.stderr);
  }

  Future<bool> deleteGallery() async {
    _downLoader.logger?.w('del gallery $gallery with path $dir');
    return _downLoader.helper
        .deleteGallery(gallery!.id)
        .then((value) => dir.delete(recursive: true))
        .then((value) => true)
        .catchError((e) {
      _downLoader.logger?.e('del gallery faild $e');
      return false;
    }, test: (error) => true);
  }

  Future<bool> fixGallery() async {
    if (tagIlleagal) {
      return deleteGallery();
    } else if (gallery != null) {
      _removeIllegalFile();
      return _downLoader.helper
          .querySql(
              'select 1 from Gallery where id=? and length!=0', [gallery!.id])
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
              return Future.wait(fs.map(
                      (img) => manager.compute(path.join(dir.path, img.name))))
                  .then((value) {
                _downLoader.logger?.d(
                    '${gallery!.id} lost ${value.length} compute time ${DateTime.now().difference(time).inSeconds} ');
                return Future.wait(value.mapIndexed((index, value) =>
                    _downLoader.helper.insertGalleryFile(
                        gallery!, fs[index], value.key, value.value))).then(
                    (value) => value.fold(true,
                        (previousValue, element) => previousValue && element));
              });
            });
          })
          .catchError((e) async {
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
