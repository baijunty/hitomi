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
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import '../gallery/gallery.dart';
import '../gallery/language.dart';
import 'sqlite_helper.dart';

class DirScanner {
  final UserConfig _config;
  final SqliteHelper _helper;
  final Logger logger;
  final DownLoader _downLoader;
  final IsolateManager<MapEntry<int, List<int>?>, String> manager;
  static final titleReg = RegExp(r'\((.+)\)(.+)');
  DirScanner(this._config, this._helper, this._downLoader, this.manager,
      this.logger) {}

  Stream<HitomiDir?> listDirs() {
    return Directory(_config.output)
        .list()
        .where((event) =>
            event is Directory && File('${event.path}/meta.json').existsSync())
        .asyncMap((event) async {
      return File('${event.path}/meta.json')
          .readAsString()
          .then((value) => HitomiDir(event as Directory, _config, _helper,
              Gallery.fromJson(value), manager, logger))
          .catchError((e) {
        logger.e('$event error $e');
        return _parseFromDir(event.path).then((value) => HitomiDir(
            event as Directory, _config, _helper, value, manager, logger));
      }, test: (error) => true);
    });
  }

  Future<Gallery?> _parseFromDir(String dir) async {
    final name = path.basename(dir);
    final match = titleReg.firstMatch(name);
    final tags = <Lable>[];
    var id = await _helper.querySql('select id from Gallery where path = ?',
        [dir]).then((value) => value?.firstOrNull?['path']);
    if (id != null) {
      logger.e('fix by id $id');
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
    logger.e('fix by search $tags');
    return _downLoader
        .fetchGallerysByTags([
          ...tags,
          ..._config.languages.map((e) => Language(name: e)),
          TypeLabel('doujinshi'),
          TypeLabel('manga')
        ], (Gallery gallery) {
          logger.i('${gallery.name} match $name');
          return name.contains(gallery.name);
        }, CancelToken())
        .then((value) =>
            value.firstWhereOrNull(
                (element) => element.language == _config.languages.first) ??
            value.first)
        .then((value) {
          logger.e('fix meta json ${value.name}');
          File(dir + '/' + 'meta.json').writeAsString(json.encode(value));
          return value;
        });
  }
}

class HitomiDir {
  final Directory dir;
  final UserConfig _config;
  final SqliteHelper _helper;
  final Gallery? gallery;
  final Logger? logger;
  final IsolateManager<MapEntry<int, List<int>?>, String> manager;
  HitomiDir(this.dir, this._config, this._helper, this.gallery, this.manager,
      this.logger);

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
          logger?.w('del file ${element.path}');
          element.deleteSync();
        } catch (e) {
          logger?.e('del failed $e');
        }
      });
    }
    return dismatchFile;
  }

  bool get tagIlleagal {
    return gallery?.tagIlleagal(_config.excludes, logger) ?? false;
  }

  Future<bool> fixGallery() async {
    if (tagIlleagal) {
      logger?.w('delete tagIlleagal from ${dir.path}');
      return _helper
          .deleteGallery(gallery!.id)
          .then((value) => dir.delete(recursive: true))
          .then((value) => true)
          .catchError((e) {
        logger?.e('del tagIlleagal faild $e');
        return false;
      }, test: (error) => true);
    } else if (gallery != null) {
      logger?.d('scan from ${dir.path}');
      _removeIllegalFile();
      return _helper.insertGallery(gallery!, dir.path).then((value) {
        return _helper
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
          logger?.d('lost ${gallery!.id} files ${fs.length}');
          var time = DateTime.now();
          return Future.wait(fs
                  .map((img) => manager.compute(path.join(dir.path, img.name))))
              .then((value) {
            logger?.d(
                '${gallery!.id} compute time ${DateTime.now().difference(time).inSeconds}');
            return Future.wait(value.mapIndexed((index, value) =>
                _helper.insertGalleryFile(gallery!, fs[index], value.key,
                    value.value))).then((value) => value.fold(
                true, (previousValue, element) => previousValue && element));
          });
        });
      }).catchError((e) {
        logger?.e('scan gallery faild $e');
        return false;
      }, test: (error) => true);
    } else {
      logger?.w('delete directory ${dir.path}');
      dir.deleteSync(recursive: true);
      return false;
    }
  }
}
