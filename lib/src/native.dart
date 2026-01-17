import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../lib.dart';
import 'hitomi_impl.dart';

Future<CommonDatabase> openSqliteDb(String dirPath, String name) async {
  final filename = path.join(dirPath, name);
  print("open sqlite3 $filename");
  return sqlite3.open(filename);
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
