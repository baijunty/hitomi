import 'package:dio/dio.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

Future<CommonDatabase> openSqliteDb(String dirPath, String name) async {
  throw UnsupportedError('Sqlite3 is unsupported on this platform.');
}

HttpClientAdapter crateHttpClientAdapter(String proxy,
    {Duration? connectionTimeout, Duration? idelTimeout}) {
  throw UnsupportedError('Sqlite3 is unsupported on this platform.');
}
