import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:hitomi/lib.dart';
import 'package:logger/logger.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

Future<CommonDatabase> openSqliteDb(String dirPath, String name) async {
  throw UnsupportedError('Sqlite3 is unsupported on this platform.');
}

Future<QueryExecutor> createDriftExecutor(
  String dirPath,
  String name, {
  Logger? logger,
}) async {
  throw UnsupportedError('Sqlite3 is unsupported on this platform.');
}

HttpClientAdapter crateHttpClientAdapter(
  String proxy, {
  Duration? connectionTimeout,
  Duration? idelTimeout,
}) {
  throw UnsupportedError('Sqlite3 is unsupported on this platform.');
}

Hitomi createHitomi(TaskManager _manager, bool localDb, String baseHttp) {
  throw UnsupportedError('Sqlite3 is unsupported on this platform.');
}
