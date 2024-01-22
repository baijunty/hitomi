import 'dart:io';

import 'package:collection/collection.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import '../gallery/gallery.dart';
import 'sqlite_helper.dart';

class DirScanner {
  final UserConfig _config;
  final SqliteHelper _helper;
  final Logger logger;
  DirScanner(this._config, this._helper, this.logger);

  Stream<HitomiDir?> listDirs() {
    return Directory(_config.output)
        .list()
        .where((event) =>
            event is Directory && File('${event.path}/meta.json').existsSync())
        .asyncMap((event) async => HitomiDir(
            event as Directory,
            _config,
            _helper,
            Gallery.fromJson(
                await File('${event.path}/meta.json').readAsString()),
            logger));
  }
}

class HitomiDir {
  final Directory dir;
  final UserConfig _config;
  final SqliteHelper _helper;
  final Gallery gallery;
  final Logger? logger;
  HitomiDir(this.dir, this._config, this._helper, this.gallery, this.logger);

  bool get dismatchFile => gallery.files.length != dir.listSync().length - 1;

  Future<int> get coverHash => File('${dir.path}/${gallery.files.first.name}')
      .readAsBytes()
      .then((value) => imageHash(value));

  bool removeIllegalFile() {
    if (dismatchFile) {
      var files = gallery.files.map((e) => e.name).toList();
      dir
          .listSync()
          .whereNot((element) =>
              files.contains(path.basename(element.path)) ||
              path.extension(element.path) == '.json')
          .forEach((element) {
        try {
          logger?.i('del file ${element.path}');
          element.deleteSync();
        } catch (e) {
          logger?.e(e);
        }
      });
    }
    return dismatchFile;
  }

  bool tagIlleagal() {
    return gallery.tags
            ?.any((element) => _config.excludes.contains(element.name)) ??
        false;
  }

  Future<bool> fixGallery() async {
    _helper.insertGallery(gallery, dir.path, await coverHash);
    return true;
  }
}
