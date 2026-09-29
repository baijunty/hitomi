import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import '../lib.dart';
import 'db/custom_functions.dart';
import 'hitomi_impl.dart';

Future<CommonDatabase> openSqliteDb(String dirPath, String name) async {
  final filename = path.join(dirPath, name);
  print("open sqlite3 $filename");
  return sqlite3.open(filename);
}

/// 打开一个 drift 执行器：直接打开原生 [Database]，用 [NativeDatabase.opened]
/// 包一层。[applyConnectionSetup] 作为 setup 回调，drift 保证它在读取 schema
/// 版本 / 跑迁移之前执行，于是 PRAGMA 和自定义函数对建表、迁移、后续查询全部生效。
Future<QueryExecutor> createDriftExecutor(
  String dirPath,
  String name, {
  Logger? logger,
}) async {
  final filename = path.join(dirPath, name);
  print("open sqlite3 $filename");
  final db = sqlite3.open(filename);
  return NativeDatabase.opened(
    db,
    setup: (database) => applyConnectionSetup(database, logger: logger),
  );
}

HttpClientAdapter crateHttpClientAdapter(
  String proxy, {
  Duration? connectionTimeout,
  Duration? idelTimeout,
}) {
  return IOHttpClientAdapter(
    createHttpClient: () {
      return HttpClient()
        ..connectionTimeout = connectionTimeout ?? Duration(seconds: 60)
        ..idleTimeout = idelTimeout ?? Duration(seconds: 120)
        ..findProxy = (u) {
          if (proxy.isEmpty) {
            return HttpClient.findProxyFromEnvironment(u);
          }
          return (proxy == "DIRECT") ? 'DIRECT' : 'PROXY ${proxy}';
        };
    },
  );
}

Hitomi createHitomi(TaskManager _manager, bool localDb, String baseHttp) {
  return fromPrefenerce(_manager, localDb);
}
