import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/http_tools.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tuple/tuple.dart';

class SqliteHelper {
  final UserConfig _config;
  static final _version = 1;
  SendPort? _sendPort;
  final result = <Completer<dynamic>>[];
  SqliteHelper(this._config);

  Future<void> init() async {
    final _receivePort = ReceivePort();
    await Isolate.spawn(databaseOpera, _receivePort.sendPort);
    var f = Completer();
    _receivePort.listen((message) {
      if (message is SendPort) {
        f.complete(message);
      } else {
        var complete = result.removeAt(0);
        if (message is Exception) {
          complete.completeError(message);
        } else {
          complete.complete(message);
        }
      }
    });
    _sendPort = await f.future;
  }

  void databaseOpera(SendPort sendPort) async {
    var recy = ReceivePort();
    sendPort.send(recy.sendPort);
    final dbPath = join(_config.output, 'user.db');
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
          if (element.query) {
            if (element.params.firstOrNull is List<dynamic>) {
              var sets = element.params.fold(<List<dynamic>, ResultSet>{},
                  (previousValue, element) {
                ResultSet r = stam!.select(element);
                previousValue[element] = r;
                return previousValue;
              });
              sendPort.send(sets);
            } else {
              var cursor = stam.select(element.params);
              sendPort.send(cursor);
            }
          } else {
            if (element.params.firstOrNull is List<dynamic>) {
              element.params.map((e) => e as List<dynamic>).forEach((element) {
                stam!.execute(element);
              });
            } else {
              stam.execute(element.params);
            }
            sendPort.send(true);
          }
        } catch (e) {
          print(e);
          sendPort.send(e);
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
    _sendPort!.send(_SqliteRequest(sql, params, true));
    result.add(f);
    return f.future;
  }

  Future<Map<List<dynamic>, ResultSet>> selectSqlMultiResultAsync(
      String sql, List<List<dynamic>> params) async {
    var f = Completer<Map<List<dynamic>, ResultSet>>();
    if (_sendPort == null) {
      await init();
    }
    _sendPort!.send(_SqliteRequest(sql, params, true));
    result.add(f);
    return f.future;
  }

  Future<bool> updateTagTable() async {
    // var rows = _db.select(
    //     'select intro from Tags where type=? by intro desc', ['author']);
    // Map<String, dynamic> author =
    //     (data['head'] as Map<String, dynamic>)['author'];
    final Map<String, dynamic> data = await http_invke(
            'https://github.com/EhTagTranslation/Database/releases/latest/download/db.text.json',
            proxy: _config.proxy)
        .then((value) => Utf8Decoder().convert(value))
        .then((value) => json.decode(value));
    if (data['data'] is List<dynamic>) {
      var rows = data['data'] as List<dynamic>;
      var params = rows
          .sublist(1)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => Tuple2(
              e['namespace'] as String, e['data'] as Map<String, dynamic>))
          .fold<List<List<dynamic>>>([], (st, e) {
        final key = ['mixed', 'other', 'cosplayer', 'temp'].contains(e.item1)
            ? 'tag'
            : e.item1.replaceAll('reclass', 'type');
        e.item2.entries.fold<List<List<dynamic>>>(st, (previousValue, element) {
          final name = element.key;
          final value = element.value as Map<String, dynamic>;
          return previousValue
            ..add([null, key, name, value['name'], value['intro']]);
        });
        return st;
      });
      return excuteSqlAsync(
          'REPLACE INTO Tags(id,type,name,translate,intro) values(?,?,?,?,?)',
          params);
    }
    return false;
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

  Future<bool> excuteSqlAsync(String sql, List<dynamic> params) async {
    var f = Completer<bool>();
    if (_sendPort == null) {
      await init();
    }
    _sendPort!.send(_SqliteRequest(sql, params, false));
    result.add(f);
    return f.future;
  }

  Future<void> insertGallery(Gallery gallery, [int? hash]) async {
    final path = join(_config.output, gallery.fixedTitle);
    var useHash = hash ??
        await imageHash(
            File(join(path, gallery.files.first.name)).readAsBytesSync());
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
          json.encode(gallery.lables().map((e) => e.index).toList()),
          json.encode(gallery.files.map((e) => e.name).toList()),
          useHash
        ]);
  }

  Future<void> updateTask(Gallery gallery, bool complete) async {
    final path = join(_config.output, gallery.fixedTitle);
    await excuteSqlAsync(
        'replace into Tasks(id,title,path,completed) values(?,?,?,?)', [
      gallery.id,
      gallery.fixedTitle,
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
  _SqliteRequest(this.sql, this.params, this.query);
  @override
  String toString() {
    return '{sql:$sql,params:$params,query:$query}';
  }
}
