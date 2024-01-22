import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

class SqliteHelper {
  final String dirPath;
  static final _version = 1;
  SendPort? _sendPort;
  final result = <String, Completer<dynamic>>{};
  Logger? logger = null;
  SqliteHelper(this.dirPath, {Logger? logger = null}) {
    this.logger = logger;
  }

  Future<void> init() async {
    final _receivePort = ReceivePort();
    await Isolate.spawn(databaseOpera, _receivePort.sendPort);
    var f = Completer();
    _receivePort.listen((message) {
      if (message is SendPort) {
        f.complete(message);
      } else if (message is _SqliteResult) {
        var complete = result.remove(message.uuid)!;
        if (message.result is Exception) {
          complete.completeError(message.result);
        } else {
          complete.complete(message.result);
        }
      }
    });
    _sendPort = await f.future;
  }

  void databaseOpera(SendPort sendPort) async {
    var recy = ReceivePort();
    sendPort.send(recy.sendPort);
    final dbPath = join(dirPath, 'user.db');
    var db = sqlite3.open(dbPath);
    db.execute('''create table  if not exists Tags(
      id Integer PRIMARY KEY autoincrement,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      translate TEXT NOT NULL,
      intro TEXT NOT NULL,
      CONSTRAINT tag UNIQUE (type,name)
      )''');
    db.execute('''create table if not exists Gallery(
      id integer PRIMARY KEY,
      path TEXT Quique,
      author TEXT,
      groupes TEXT,
      serial TEXT,
      language TEXT not null,
      title TEXT not NULL,
      tags TEXT,
      files TEXT,
      hash INTEGER not NULL
      )''');
    db.execute('''create table if not exists Tasks(
      id integer PRIMARY KEY,
      title Text not null,
      path TEXT not null,
      completed bool default 0
      )''');
    final stmt = db.prepare('PRAGMA user_version;');
    final result = stmt.select();
    var version = result.first.columnAt(0) as int;
    if (version != _version) {
      db.execute('PRAGMA user_version=$_version;');
    }
    await recy.forEach((element) async {
      if (element is _SqliteRequest) {
        PreparedStatement? stam;
        try {
          stam = db.prepare(element.sql);
          logger?.d('excel sql ${element.sql}');
          if (element.query) {
            if (element.params.firstOrNull is List<dynamic>) {
              var sets = element.params.fold(<List<dynamic>, ResultSet>{},
                  (previousValue, element) {
                ResultSet r = stam!.select(element);
                previousValue[element] = r;
                return previousValue;
              });
              logger?.d('excel sql result ${sets}');
              sendPort.send(_SqliteResult(uuid: element.uuid, result: sets));
            } else {
              var cursor = stam.select(element.params);
              logger?.d('excel sql result ${cursor}');
              sendPort.send(_SqliteResult(uuid: element.uuid, result: cursor));
            }
          } else {
            if (element.params.firstOrNull is List<dynamic>) {
              element.params.map((e) => e as List<dynamic>).forEach((element) {
                stam!.execute(element);
              });
            } else {
              stam.execute(element.params);
            }
            sendPort.send(_SqliteResult(uuid: element.uuid, result: true));
          }
        } catch (e) {
          sendPort.send(_SqliteResult(uuid: element.uuid, result: e));
          logger?.e('excel sql result ${e}');
        } finally {
          stam?.dispose();
        }
      }
    });
  }

  Future<ResultSet> selectSqlAsync(String sql, List<dynamic> params) async {
    var f = Completer<ResultSet>();
    if (_sendPort == null) {
      await init();
    }
    final req = _SqliteRequest(sql, params, true);
    _sendPort!.send(req);
    result[req.uuid] = f;
    return f.future;
  }

  Future<Map<List<dynamic>, ResultSet>> selectSqlMultiResultAsync(
      String sql, List<List<dynamic>> params) async {
    var f = Completer<Map<List<dynamic>, ResultSet>>();
    if (_sendPort == null) {
      await init();
    }
    final req = _SqliteRequest(sql, params, true);
    _sendPort!.send(req);
    result[req.uuid] = f;
    return f.future;
  }

  Future<bool> updateTagTable(List<List<dynamic>> params) async {
    return excuteSqlAsync(
        'REPLACE INTO Tags(id,type,name,translate,intro) values(?,?,?,?,?)',
        params);
  }

  Future<List<Lable>> fetchLablesFromSql(List<String> names) async {
    var sets = await selectSqlMultiResultAsync(
        'select * from Tags where name=? or translate=?',
        names.map((name) => [name.toLowerCase(), name.toLowerCase()]).toList());
    return names.map((e) {
      var set = sets.entries
          .firstWhereOrNull((element) => element.key.first == e.toLowerCase())
          ?.value
          .first;
      if (set?.isNotEmpty == true) {
        return fromString(set!['type'], set['name']);
      }
      return QueryText(e);
    }).toList();
  }

  Future<ResultSet?> querySql(String sql,
      [List<dynamic> params = const []]) async {
    var set = await selectSqlAsync(sql, params = params);
    if (set.isNotEmpty) {
      return set;
    }
    return null;
  }

  Future<List<Lable>> mapToLabel(List<String> names) async {
    var set = await selectSqlMultiResultAsync(
        'select * from Tags where name = ?', names.map((e) => [e]).toList());
    return names.map((e) {
      var f = set.entries
          .firstWhereOrNull((element) => element.key.equals([e]))
          ?.value
          .first;
      if (f != null) {
        return fromString(f['type'], f['name']);
      }
      return QueryText(e);
    }).toList();
  }

  Future<bool> excuteSqlAsync(String sql, List<dynamic> params) async {
    var f = Completer<bool>();
    if (_sendPort == null) {
      await init();
    }
    final req = _SqliteRequest(sql, params, false);
    _sendPort!.send(req);
    result[req.uuid] = f;
    return f.future;
  }

  Future<void> insertGallery(Gallery gallery, String path, [int? hash]) async {
    var useHash = hash ??
        await File(join(path, gallery.files.first.name))
            .readAsBytes()
            .then((value) => imageHash(value))
            .catchError((e) => 0, test: (e) => true);
    await excuteSqlAsync(
        'replace into Gallery(id,path,author,groupes,serial,language,title,tags,files,hash) values(?,?,?,?,?,?,?,?,?,?)',
        [
          gallery.id,
          path,
          gallery.artists?.first.translate,
          gallery.groups?.first.translate,
          gallery.parodys?.first.translate,
          gallery.language,
          gallery.name,
          json.encode(gallery.lables().toList()),
          json.encode(gallery.files.map((e) => e.name).toList()),
          useHash
        ]);
  }

  Future<void> updateTask(
      dynamic id, String title, String path, bool complete) async {
    await excuteSqlAsync(
        'replace into Tasks(id,title,path,completed) values(?,?,?,?)', [
      id,
      title,
      path,
      complete,
    ]);
  }

  Future<void> removeTask(dynamic id) async {
    await excuteSqlAsync('delete from Tasks where id =?', [id]);
  }
}

class _SqliteRequest {
  String sql;
  List<dynamic> params;
  bool query;
  String uuid = Uuid().v4();
  _SqliteRequest(this.sql, this.params, this.query);
  @override
  String toString() {
    return '{sql:$sql,params:$params,query:$query}';
  }
}

class _SqliteResult {
  final String uuid;
  final dynamic result;

  _SqliteResult({required this.uuid, required this.result});
}
