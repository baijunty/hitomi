import 'dart:convert';

import 'package:dio/browser.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/wasm.dart' show IndexedDbFileSystem, WasmSqlite3;

import '../lib.dart';

Future<CommonDatabase> openSqliteDb(String dirPath, String name) async {
  // Please download `sqlite3.wasm` from https://github.com/simolus3/sqlite3.dart/releases
  // into the `web/` dir of your Flutter app. See `README.md` for details.
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fileSystem = await IndexedDbFileSystem.open(dbName: name);
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
  return sqlite.open(name);
}

HttpClientAdapter crateHttpClientAdapter(String proxy,
    {Duration? connectionTimeout, Duration? idelTimeout}) {
  return BrowserHttpClientAdapter();
}

Hitomi crateHitomi(TaskManager _manager, bool localDb, String baseHttp) {
  return WebHitomi(
      _manager.dio, localDb, _manager.config.auth, 'http://${baseHttp}');
}

class WebHitomi implements Hitomi {
  final Dio dio;
  final String bashHttp;
  final bool localDb;
  final String auth;
  WebHitomi(this.dio, this.localDb, this.auth, this.bashHttp);

  @override
  Future<bool> downloadImages(Gallery gallery,
      {bool usePrefence = true, CancelToken? token}) async {
    return false;
  }

  @override
  Future<Gallery> fetchGallery(id,
      {usePrefence = true, CancelToken? token}) async {
    return dio
        .post<String>('$bashHttp/proxy/fetchGallery',
            data: json.encode({
              'id': id,
              'usePrefence': usePrefence,
              'auth': auth,
              'local': localDb
            }))
        .then((value) => Gallery.fromJson(value.data!));
  }

  @override
  Future<List<int>> fetchImageData(Image image,
      {String refererUrl = '',
      CancelToken? token,
      int id = 0,
      ThumbnaiSize size = ThumbnaiSize.smaill}) {
    return dio
        .post<String>('$bashHttp/proxy/fetchImageData',
            data: json.encode({
              'image': image,
              'referer': refererUrl,
              'size': size.name,
              'auth': auth,
              'id': id,
              'local': localDb
            }))
        .then((value) => json.decode(value.data!) as List<int>);
  }

  @override
  void registerCallBack(Future<bool> Function(Message msg) callBack) {}

  @override
  void removeCallBack(Future<bool> Function(Message msg) callBack) {}

  @override
  Future<List<int>> search(List<Label> include,
      {List<Label> exclude = const [], int page = 1, CancelToken? token}) {
    return dio
        .post<String>('$bashHttp/proxy/search',
            data: json.encode({
              'tags': include,
              'excluds': exclude,
              'page': page,
              'auth': auth,
              'local': localDb
            }))
        .then((value) => json.decode(value.data!) as List<int>);
  }

  @override
  String buildImageUrl(Image image,
      {ThumbnaiSize size = ThumbnaiSize.smaill, int id = 0}) {
    return '$bashHttp/${size == ThumbnaiSize.origin ? 'image' : 'thumb'}/${id}/${image.hash}?size=${size.name}&local=${localDb ? 1 : 0}';
  }

  @override
  Future<List<Gallery>> viewByTag(Label tag,
      {int page = 1, CancelToken? token}) async {
    return dio
        .post<String>('$bashHttp/proxy/viewByTag',
            data: json.encode({
              'tags': [tag],
              'page': page,
              'auth': auth,
              'local': localDb
            }))
        .then((value) {
      return json.decode(value.data!) as List<dynamic>;
    }).then((value) {
      return value.map((element) => Gallery.fromJson(element)).toList();
    });
  }
}
