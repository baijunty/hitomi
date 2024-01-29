import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

class SqliteHelper {
  final String dirPath;
  static final _version = 4;
  Logger? logger = null;
  late Database db;
  SqliteHelper(this.dirPath, {Logger? logger = null}) {
    this.logger = logger;
    final dbPath = join(dirPath, 'user.db');
    db = sqlite3.open(dbPath);
    init();
  }

  void init() async {
    createTables(db);
    final stmt = db.prepare('PRAGMA user_version;');
    final result = stmt.select();
    var version = result.first.columnAt(0) as int;
    if (version != _version) {
      if (version < _version) {
        dataBaseUpgrade(db, version);
      } else if (version > _version) {
        dateBaseDowngrade(db, version);
      }
      db.execute('PRAGMA user_version=$_version;');
    }
  }

  T databaseOpera<T>(_SqliteRequest element, T operate(dynamic obj)) {
    PreparedStatement? stam;
    try {
      stam = db.prepare(element.sql);
      logger?.d('excel sql ${element.sql} params ${element.params.length}');
      if (element.query) {
        if (element.params.firstOrNull is List<dynamic>) {
          var sets = element.params.fold(<List<dynamic>, ResultSet>{},
              (previousValue, element) {
            ResultSet r = stam!.select(element);
            previousValue[element] = r;
            return previousValue;
          });
          return operate(sets);
        } else {
          var cursor = stam.select(element.params);
          return operate(cursor);
        }
      } else {
        if (element.params.firstOrNull is List<dynamic>) {
          element.params.map((e) => e as List<dynamic>).forEach((element) {
            stam!.execute(element);
          });
        } else {
          stam.execute(element.params);
        }
        return operate(true);
      }
    } catch (e) {
      logger?.e('excel sql result ${e}');
      throw e;
    } finally {
      stam?.dispose();
    }
  }

  void createTables(Database db) {
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
      character TEXT,
      language TEXT not null,
      title TEXT not NULL,
      tags TEXT,
      createDate TEXT,
      date INTEGER,
      mark INTEGER default 0,
      length integer
      )''');
    db.execute('''create table if not exists GalleryFile(
      gid INTEGER,
      hash TEXT not NULL,
      name TEXT not NULL,
      width integer,
      height integer,
      fileHash integer,
      thumb BLOB,
      PRIMARY KEY(gid,hash),
      FOREIGN KEY(gid) REFERENCES Gallery(id)  ON DELETE CASCADE
      )''');
    db.execute('''create table if not exists Tasks(
      id integer PRIMARY KEY,
      title Text not null,
      path TEXT not null,
      completed bool default 0
      )''');
  }

  void dataBaseUpgrade(Database db, int oldVersion) {
    switch (oldVersion) {
      case 1:
      case 2:
      case 3:
        {
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
              """insert into  Gallery(id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length) select id,path,author,groupes,serial,null,language,title,null,null,0,0,0 from GalleryTemp""");
          db.execute("drop table GalleryTemp");
        }
    }
  }

  void dateBaseDowngrade(Database db, int oldVersion) {}

  Future<ResultSet> selectSqlAsync(String sql, List<dynamic> params) async {
    final req = _SqliteRequest(sql, params, true);
    return databaseOpera(req, (obj) => obj as ResultSet);
  }

  Future<Map<List<dynamic>, ResultSet>> selectSqlMultiResultAsync(
      String sql, List<List<dynamic>> params) async {
    final req = _SqliteRequest(sql, params, true);
    return databaseOpera(req, (obj) => obj as Map<List<dynamic>, ResultSet>);
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
    final req = _SqliteRequest(sql, params, false);
    return databaseOpera(req, (obj) => obj as bool);
  }

  Future<bool> insertGallery(Gallery gallery, String path) async {
    return await excuteSqlAsync(
        'replace into Gallery(id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length) values(?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          gallery.id,
          basename(path),
          json.encode(gallery.artists?.map((e) => e.name).toList()),
          json.encode(gallery.groups?.map((e) => e.name).toList()),
          json.encode(gallery.parodys?.map((e) => e.name).toList()),
          json.encode(gallery.characters?.map((e) => e.name).toList()),
          gallery.language,
          gallery.name,
          json.encode(gallery.tags?.groupListsBy((element) => element.type).map(
              (key, value) =>
                  MapEntry(key, value.map((e) => e.name).toList()))),
          gallery.date,
          DateTime.now().millisecondsSinceEpoch,
          0,
          gallery.files.length
        ]);
  }

  Future<bool> insertGalleryFile(
      Gallery gallery, Image image, int hash, List<int>? thumb) async {
    return excuteSqlAsync(
        'replace into GalleryFile(gid,hash,name,width,height,fileHash,thumb) values(?,?,?,?,?,?,?)',
        [
          gallery.id,
          image.hash,
          image.name,
          image.width,
          image.height,
          hash,
          thumb
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

  Future<bool> removeTask(dynamic id) async {
    return excuteSqlAsync('delete from Tasks where id =?', [id]);
  }

  Future<bool> deleteGallery(dynamic id) async {
    return excuteSqlAsync('delete from Gallery where id =?', [id]);
  }

  Future<bool> deleteGalleryFile(dynamic id, String hash) async {
    return excuteSqlAsync(
        'delete from GalleryFile where gid =? and hash=?', [id, hash]);
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
