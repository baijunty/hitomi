import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/http_tools.dart';
import 'package:path/path.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tuple/tuple.dart';

import 'prefenerce.dart';

class SqliteHelper {
  final UserContext context;
  late final Database _db;
  static final _version = 1;
  int get version {
    final stmt = _db.prepare('PRAGMA user_version;');
    try {
      final result = stmt.select();
      return result.first.columnAt(0) as int;
    } finally {
      stmt.dispose();
    }
  }

  SqliteHelper(this.context) {
    final dbPath = join(context.outPut, 'user.db');
    _db = sqlite3.open(dbPath);
    initTables();
    if (version != _version) {
      updateDataBase();
      _db.execute('PRAGMA user_version=$_version;');
    }
  }

  void initTables() {
    _db.execute('''create table  if not exists Tags(
      id Integer PRIMARY KEY autoincrement,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      translate TEXT NOT NULL,
      intro TEXT NOT NULL,
      CONSTRAINT tag UNIQUE (type,name)
      )''');
    _db.execute('''create table if not exists Gallery(
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
  }

  void updateDataBase() {}

  Future<bool> updateTagTable() async {
    // var rows = _db.select(
    //     'select intro from Tags where type=? by intro desc', ['author']);
    // Map<String, dynamic> author =
    //     (data['head'] as Map<String, dynamic>)['author'];
    final Map<String, dynamic> data = await http_invke(
            'https://github.com/EhTagTranslation/Database/releases/latest/download/db.text.json',
            proxy: context.proxy)
        .then((value) => Utf8Decoder().convert(value))
        .then((value) => json.decode(value));
    if (data['data'] is List<dynamic>) {
      var rows = data['data'] as List<dynamic>;
      final stam = _db.prepare(
          'REPLACE INTO Tags(id,type,name,translate,intro) values(?,?,?,?,?) ');
      rows
          .sublist(1)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => Tuple2(
              e['namespace'] as String, e['data'] as Map<String, dynamic>))
          .fold<PreparedStatement>(stam, (st, e) {
        final key = ['mixed', 'other', 'cosplayer', 'temp'].contains(e.item1)
            ? 'tag'
            : e.item1.replaceAll('reclass', 'type');
        e.item2.entries.fold<PreparedStatement>(st, (previousValue, element) {
          final name = element.key;
          final value = element.value as Map<String, dynamic>;
          return previousValue
            ..execute([null, key, name, value['name'], value['intro']]);
        });
        return st;
      });
      stam.dispose();
    }
    return true;
  }

  Map<String, dynamic>? getMatchLable(Lable lable) {
    final set = _db.select('select * from Tags where type=? and name=?',
        [lable.sqlType, lable.name]);
    if (set.isNotEmpty) {
      return set.first;
    }
    return null;
  }

  Lable getLableFromKey(String name) {
    var row = context.helper.querySql(
        'select * from Tags where name=? or translate=?',
        [name.toLowerCase(), name.toLowerCase()]);
    if (row?.isNotEmpty ?? false) {
      var type = row!.first['type'];
      var name = row.first['name'];
      return fromString(type, name);
    }
    return QueryText(name);
  }

  ResultSet? querySql(String sql, [List<dynamic> params = const []]) {
    var set = _db.select(sql, params = params);
    if (set.isNotEmpty) {
      return set;
    }
    return null;
  }

  void excuteWithRow(String sql, void doWithStam(PreparedStatement statement)) {
    final stam = _db.prepare(sql);
    try {
      doWithStam(stam);
    } catch (e) {
      print(e);
    } finally {
      stam.dispose();
    }
  }

  void excuteSql(String sql, [List<dynamic> params = const []]) {
    _db.execute(sql, params);
  }

  void insertGallery(Gallery gallery, [int? hash]) async {
    final path = join(context.outPut, gallery.fixedTitle);
    var useHash = hash ??
        await imageHash(
            File(join(path, gallery.files.first.name)).readAsBytesSync());
    excuteWithRow(
        'replace into Gallery(id,path,author,groupes,serial,language,title,tags,files,hash) values(?,?,?,?,?,?,?,?,?,?)',
        (statement) {
      statement.execute([
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
    });
  }
}
