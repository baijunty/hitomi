import 'package:dio/browser.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/wasm.dart' show WasmDatabase;
import 'package:logger/logger.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/wasm.dart' show IndexedDbFileSystem, WasmSqlite3;
import '../lib.dart';
import 'db/custom_functions.dart';
import 'hitomi_impl.dart';

Future<CommonDatabase> openSqliteDb(String dirPath, String name) async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  final fileSystem = await IndexedDbFileSystem.open(dbName: name);
  sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
  return sqlite.open(name);
}

/// 打开一个 drift 执行器：复用 [openSqliteDb] 拿到 WASM 连接，再用
/// [WasmDatabase.opened] 包一层。[applyConnectionSetup] 作为 setup 回调，
/// drift 保证它在读取 schema 版本 / 跑迁移之前执行。
Future<QueryExecutor> createDriftExecutor(
  String dirPath,
  String name, {
  Logger? logger,
}) async {
  final db = await openSqliteDb(dirPath, name);
  return WasmDatabase.opened(
    db,
    setup: (database) => applyConnectionSetup(database, logger: logger),
  );
}

HttpClientAdapter crateHttpClientAdapter(
  String proxy, {
  Duration? connectionTimeout,
  Duration? idelTimeout,
}) {
  return BrowserHttpClientAdapter();
}

Hitomi createHitomi(TaskManager _manager, bool localDb, String baseHttp) {
  return WebHitomi(_manager.dio, localDb, _manager.config.auth, baseHttp);
}
