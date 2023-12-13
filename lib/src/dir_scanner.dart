import 'dart:io';

import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';

import '../gallery/gallery.dart';
import 'sqlite_helper.dart';

class DirScanner {
  final UserConfig _config;
  final SqliteHelper _helper;
  DirScanner(this._config, this._helper);

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
                await File('${event.path}/meta.json').readAsString())));
  }
}

class HitomiDir {
  final Directory path;
  final UserConfig _config;
  final SqliteHelper _helper;
  final Gallery gallery;
  HitomiDir(this.path, this._config, this._helper, this.gallery);

  bool get dismatchFile => gallery.files.length != path.listSync().length - 1;

  Future<int> get coverHash => File('${path.path}/${gallery.files.first.name}')
      .readAsBytes()
      .then((value) => imageHash(value));
}
