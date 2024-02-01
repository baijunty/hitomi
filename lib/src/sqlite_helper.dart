import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';

class SqliteHelper {
  final String dirPath;
  static final _version = 5;
  Logger? logger = null;
  late Database db;
  SqliteHelper(
    this.dirPath, {
    String dbName = 'user.db',
    Logger? logger = null,
  }) {
    this.logger = logger;
    final dbPath = join(dirPath, dbName);
    db = sqlite3.open(dbPath);
    init();
  }

  bool jsonKeyContains(List<Object?> arguments) {
    if (arguments.length == 2) {
      try {
        var data = json.decode(arguments[0].toString());
        if (data is Map<String, dynamic>) {
          return data.keys.contains(arguments[1]);
        }
      } catch (e) {
        logger?.e('illgal json $e');
      }
    }
    return false;
  }

  bool jsonValueContains(List<Object?> arguments) {
    if (arguments.length > 1) {
      try {
        print(arguments);
        var data = json.decode(arguments[0].toString());
        if (data is Map<String, dynamic>) {
          if (arguments.length == 3) {
            var value = data[arguments[1]].toString();
            return value.contains(arguments[2].toString());
          } else {
            return data.values
                .any((e) => e.toString().contains(arguments[1].toString()));
          }
        } else if (data is List<dynamic>) {
          return data.contains(arguments[1].toString());
        }
      } catch (e) {
        logger?.e('illgal json $e');
      }
    }
    return false;
  }

  int hashDistance(List<Object?> arguments) {
    if (arguments.length == 2 &&
        arguments.every((element) => element! is int)) {
      return compareHashDistance(arguments[0] as int, arguments[1] as int);
    }
    return 64;
  }

  void init() async {
    createTables(db);
    final stmt = db.prepare('PRAGMA user_version;');
    db.createFunction(
        functionName: 'json_key_contains',
        function: jsonKeyContains,
        argumentCount: AllowedArgumentCount(2));
    db.createFunction(
        functionName: 'json_value_contains',
        function: jsonValueContains,
        argumentCount: AllowedArgumentCount.any());
    db.createFunction(
        functionName: 'hash_distance',
        function: hashDistance,
        argumentCount: AllowedArgumentCount(2));
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

  T databaseOpera<T>(String sql, T operate(PreparedStatement statement),
      {bool releaseOnce = true}) {
    PreparedStatement? stam;
    try {
      stam = db.prepare(sql);
      return operate(stam);
    } catch (e) {
      logger?.e('excel sql faild ${e}');
      throw e;
    } finally {
      if (releaseOnce) {
        stam?.dispose();
      }
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
      artist TEXT,
      groupes TEXT,
      series TEXT,
      character TEXT,
      language TEXT not null,
      title TEXT not NULL,
      tag TEXT,
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
      case 4:
        {
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
              """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,date,mark,length) select id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length from GalleryTemp""");
          db.execute("drop table GalleryTemp");
        }
    }
  }

  void dateBaseDowngrade(Database db, int oldVersion) {}

  Future<Map<List<dynamic>, ResultSet>> selectSqlMultiResultAsync(
      String sql, List<List<dynamic>> params) async {
    var r = databaseOpera(sql, (stmt) {
      return params.fold(<List<dynamic>, ResultSet>{},
          (previousValue, element) {
        ResultSet r = stmt.select(element);
        previousValue[element] = r;
        return previousValue;
      });
    });
    return r;
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

  Future<ResultSet> querySql(String sql,
      [List<dynamic> params = const []]) async {
    return databaseOpera(sql, (stmt) => stmt.select(params));
  }

  Future<CursorImpl> querySqlByCursor(String sql,
      [List<dynamic> params = const []]) async {
    return databaseOpera(
        sql, (stmt) => stmt.selectCursor(params).asIterable(stmt),
        releaseOnce: false);
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
    databaseOpera(sql, (stmt) => stmt.execute(params));
    return true;
  }

  Future<bool> excuteSqlMultiParams(
      String sql, List<List<dynamic>> params) async {
    databaseOpera(
        sql,
        (stmt) => params.forEach((element) {
              stmt.execute(element);
            }));
    return true;
  }

  Future<bool> insertGallery(Gallery gallery, String path) async {
    return await excuteSqlAsync(
        'replace into Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,date,mark,length) values(?,?,?,?,?,?,?,?,?,?,?,?,?)',
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

  Future<ResultSet?> queryGallery(
      {String? author = null, String? group = null}) async {
    return querySql(
        '''select g.*,gf.fileHash,gf.name from (select g.* from Gallery g,json_each(g.artist) ja where (json_valid(g.artist)=1 and ja.value in (?) ) union all 
select g.* from Gallery g,json_each(g.groupes) jg where (json_valid(g.groupes)=1 and jg.value in (?))) as g LEFT JOIN GalleryFile gf  on gf.gid =g.id where gf.hash is not null group by g.id order by gf.name''',
        [author, group]);
  }

  Future<ResultSet?> queryGalleryImpl(String type, Lable lable) async {
    return querySql(
        '''select g.*,gf.fileHash,gf.name from (select * from Gallery where json_value_contains(?,?,?)=1 ) as g LEFT JOIN GalleryFile gf  on gf.gid =g.id where gf.hash is not null group by g.id order by gf.name''',
        [type, lable.type, lable.name]);
  }

  Future<ResultSet?> queryGalleryByTag(Lable lable) async {
    return queryGalleryImpl('tag', lable);
  }

  Future<ResultSet?> queryGalleryById(dynamic id) async {
    return querySql(
        '''select g.*,gf.fileHash,gf.name from (select * from Gallery where id=? ) as g LEFT JOIN GalleryFile gf  on gf.gid =g.id where gf.hash is not null group by g.id order by gf.name''',
        [id]);
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
    logger?.w('del gallery with id $id');
    return excuteSqlAsync('delete from Gallery where id =?', [id]).then(
        (value) =>
            excuteSqlAsync('delete from GalleryFile where gid =?', [id]));
  }

  Future<bool> deleteGalleryFile(dynamic id, String hash) async {
    return excuteSqlAsync(
        'delete from GalleryFile where gid =? and hash=?', [id, hash]);
  }
}
