import 'package:dio/browser.dart';
import 'package:dio/dio.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/wasm.dart' show IndexedDbFileSystem, WasmSqlite3;
import '../lib.dart';
import 'hitomi_impl.dart';

Future<CommonDatabase> openSqliteDb(String dirPath, String name) async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fileSystem = await IndexedDbFileSystem.open(dbName: name);
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
  return sqlite.open(name);
}

HttpClientAdapter crateHttpClientAdapter(String proxy,
    {Duration? connectionTimeout, Duration? idelTimeout}) {
  return BrowserHttpClientAdapter();
}

Hitomi createHitomi(TaskManager _manager, bool localDb, String baseHttp) {
  return WebHitomi(_manager.dio, localDb, _manager.config.auth, baseHttp);
}
