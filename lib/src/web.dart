import 'package:dio/browser.dart';
import 'package:dio/dio.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/wasm.dart' show IndexedDbFileSystem, WasmSqlite3;

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
