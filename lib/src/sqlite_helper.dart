import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';
import 'multi_paltform.dart' show openSqliteDb;

class SqliteHelper {
  final String _dirPath;
  static final _version = 8;
  Logger? _logger = null;
  late CommonDatabase _db;
  CommonDatabase? __db;
  String dbName;
  SqliteHelper(
    this._dirPath, {
    this.dbName = 'user.db',
    Logger? logger = null,
  }) {
    this._logger = logger;
  }

  Future<void> checkInit() async {
    if (__db == null) {
      await openSqliteDb(_dirPath, dbName).then((value) {
        __db = value;
        _db = value;
      }).then((value) => init());
    }
  }

  bool jsonKeyContains(List<Object?> arguments) {
    if (arguments.length == 2) {
      try {
        var data = json.decode(arguments[0].toString());
        if (data is Map<String, dynamic>) {
          return data.keys.contains(arguments[1]);
        }
      } catch (e) {
        _logger?.e('jsonKeyContains illgal json $e with ${arguments[0]}');
      }
    }
    return false;
  }

  bool jsonValueContains(List<Object?> arguments) {
    if (arguments.length > 1 && (arguments[0]?.toString() ?? '').isNotEmpty) {
      try {
        var data = json.decode(arguments[0].toString());
        if (data is Map<String, dynamic>) {
          if (arguments.length == 3) {
            var value = data[arguments[2]].toString();
            return value.contains(arguments[1].toString());
          } else {
            return data.values
                .any((e) => e.toString().contains(arguments[1].toString()));
          }
        } else if (data is List<dynamic>) {
          return data.contains(arguments[1].toString());
        }
      } catch (e) {
        _logger?.e('jsonValueContains illgal json $e with ${arguments[0]}');
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
    __db = _db;
    createTables(_db);
    final stmt = _db.prepare('PRAGMA user_version;');
    _db.createFunction(
        functionName: 'json_key_contains',
        function: jsonKeyContains,
        argumentCount: AllowedArgumentCount(2));
    _db.createFunction(
        functionName: 'json_value_contains',
        function: jsonValueContains,
        argumentCount: AllowedArgumentCount.any());
    _db.createFunction(
        functionName: 'hash_distance',
        function: hashDistance,
        argumentCount: AllowedArgumentCount(2));
    final result = stmt.select();
    var version = result.first.columnAt(0) as int;
    if (version != _version) {
      if (version < _version) {
        dataBaseUpgrade(_db, version);
      } else if (version > _version) {
        dateBaseDowngrade(_db, version);
      }
      _db.execute('PRAGMA user_version=$_version;');
    }
    _db.execute('PRAGMA journal_mode = WAL;');
  }

  Future<T> databaseOpera<T>(
      String sql, T operate(CommonPreparedStatement statement),
      {bool releaseOnce = true}) async {
    CommonPreparedStatement? stam;
    try {
      await checkInit();
      stam = _db.prepare(sql);
      return operate(stam);
    } catch (e, stack) {
      _logger?.e('excel sql faild ${stack}');
      return Future.error('$sql error', stack);
    } finally {
      if (releaseOnce) {
        stam?.dispose();
      }
    }
  }

  void createTables(CommonDatabase db) {
    db.execute('''create table  if not exists Tags(
      id Integer PRIMARY KEY autoincrement,
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      translate TEXT NOT NULL,
      intro TEXT NOT NULL,
      links TEXT,
      superior TEXT,
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
      type Text,
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
    db.execute('''create table if not exists UserLog(
      id integer,
      mark integer,
      type integer default 0,
      content Text,
      extension BLOB,
      PRIMARY KEY(id,type)
      )''');
  }

  Future<bool> insertUserLog(int id, int type,
      {int mark = 0, String? content, List<int> extension = const []}) async {
    return excuteSqlAsync(
        'replace into UserLog(id,mark,type,content,extension) values (?,?,?,?)',
        [id, mark, type, content, extension]);
  }

  Future<T?> readlData<T>(
      String tableNmae, String name, Map<String, dynamic> params) async {
    var where = params.entries.fold(
        StringBuffer(), (acc, element) => acc..write('${element.key}=? and'));
    return querySql('select $name from $tableNmae where $where 1=1',
            params.values.toList())
        .then((value) => value.firstOrNull?['$name'] as T?);
  }

  Future<bool> delete(String tableNmae, Map<String, dynamic> params) async {
    var where = params.entries.fold(
        StringBuffer(), (acc, element) => acc..write('${element.key}=? and'));
    return excuteSqlAsync(
        'delete from $tableNmae where $where 1=1', params.values.toList());
  }

  void dataBaseUpgrade(CommonDatabase db, int oldVersion) {
    switch (oldVersion) {
      case 1:
      case 2:
      case 3:
        {
          db.execute("drop table if exists  GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
              """insert into  Gallery(id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length) select id,path,author,groupes,serial,null,language,title,null,null,0,0,0 from GalleryTemp""");
          db.execute("drop table GalleryTemp");
        }
      case 4:
        {
          db.execute("drop table if exists  GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
              """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,date,mark,length) select id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length from GalleryTemp""");
          db.execute("drop table GalleryTemp");
        }
      case 5:
        {
          db.execute("drop table if exists  GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
              """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length) select id,path,artist,groupes,series,character,language,title,tag,createDate,null,date,mark,length from GalleryTemp""");
          db.execute("drop table GalleryTemp");
        }
      case 6:
        {
          db.execute("drop table if exists   TagsTemp ");
          db.execute("ALTER table Tags rename to TagsTemp");
          createTables(db);
          db.execute(
              """insert into  Tags(id,type,name,translate,intro,links,superior) select id,type,name,translate,intro,null,null from TagsTemp""");
          db.execute("drop table TagsTemp");
        }
      case 7:
        {
          db.execute("drop table if exists UserLogTemp ");
          db.execute("ALTER table UserLog rename to UserLogTemp");
          createTables(db);
          db.execute(
              """insert into  UserLog(id,mark,type,content,extension) select id,mark,0,content,extension from UserLogTemp""");
          db.execute("drop table UserLogTemp");
        }
    }
  }

  void dateBaseDowngrade(CommonDatabase db, int oldVersion) {}

  Future<Map<List<dynamic>, ResultSet>> selectSqlMultiResultAsync(
      String sql, List<List<dynamic>> params) async {
    var r = databaseOpera(sql, (stmt) {
      return params.fold(<List<dynamic>, ResultSet>{},
          (previousValue, element) {
        try {
          ResultSet r = stmt.select(element);
          previousValue[element] = r;
          return previousValue;
        } catch (e) {
          _logger?.e('$sql error parmas $element $e');
          throw e;
        }
      });
    });
    return r;
  }

  Future<bool> updateTagTable(List<List<dynamic>> params) async {
    return excuteSqlMultiParams(
        'REPLACE INTO Tags(id,type,name,translate,intro,links,superior) values(?,?,?,?,?,?,?)',
        params);
  }

  Future<List<Map<String, dynamic>>> fetchLabelsFromSql(String name) async {
    var sets = await querySql(
        'select type,name,translate,intro,links from Tags where name like ? or translate like ?',
        [name.toLowerCase(), name.toLowerCase()]);
    return sets.toList();
  }

  Future<ResultSet> querySql(String sql,
      [List<dynamic> params = const []]) async {
    return databaseOpera(sql, (stmt) => stmt.select(params));
  }

  Future<Stream<Row>> querySqlByCursor(String sql,
      [List<dynamic> params = const []]) async {
    return databaseOpera(
        sql, (stmt) => stmt.selectCursor(params).asStream(stmt),
        releaseOnce: false);
  }

  Future<List<Label>> mapToLabel(List<String> names) async {
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
    await databaseOpera(sql, (stmt) => stmt.execute(params));
    return true;
  }

  Future<bool> excuteSqlMultiParams(
      String sql, List<List<dynamic>> params) async {
    await databaseOpera(
        sql,
        (stmt) => params.forEach((element) {
              stmt.execute(element);
            }));
    return true;
  }

  Future<bool> insertGallery(Gallery gallery, FileSystemEntity path) async {
    return await excuteSqlAsync(
        'replace into Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          gallery.id,
          basename(path.path),
          gallery.artists == null
              ? null
              : json.encode(gallery.artists?.map((e) => e.name).toList()),
          gallery.groups == null
              ? null
              : json.encode(gallery.groups?.map((e) => e.name).toList()),
          gallery.parodys == null
              ? null
              : json.encode(gallery.parodys?.map((e) => e.name).toList()),
          gallery.characters == null
              ? null
              : json.encode(gallery.characters?.map((e) => e.name).toList()),
          gallery.language,
          gallery.name,
          gallery.tags == null
              ? null
              : json.encode(gallery.tags
                  ?.groupListsBy((element) => element.type)
                  .map((key, value) =>
                      MapEntry(key, value.map((e) => e.name).toList()))),
          gallery.date,
          gallery.type,
          path.statSync().modified.millisecondsSinceEpoch,
          0,
          gallery.files.length
        ]);
  }

  Future<ResultSet> queryGalleryByLabel(String type, Label label) async {
    return querySql(
        'select * from Gallery where json_value_contains($type,?,?)=1',
        [label.name, label.type]);
  }

  Future<ResultSet> queryGalleryByTag(Label label) async {
    return queryGalleryByLabel('tag', label);
  }

  Future<ResultSet> queryGalleryById(dynamic id) async {
    return querySql('''select * from Gallery where id=?''', [id]);
  }

  Future<ResultSet> queryImageHashsById(dynamic id) async {
    return querySql(
        '''select * from GalleryFile where gid=? order by name''', [id]);
  }

  Future<Map<int, List<int>>> queryImageHashsByLabel(String type, String name) {
    return querySqlByCursor(
        'select gf.gid,gf.fileHash,gf.name,g.path,g.length from Gallery g,json_each(g.${type}) ja left join GalleryFile gf on g.id=gf.gid where (json_valid(g.${type})=1 and ja.value = ? and gf.gid is not null) order by gf.gid,gf.name',
        [
          name
        ]).then((value) => value.fold(<int, List<int>>{}, (previous, element) {
          previous[element['gid']] =
              ((previous[element['gid']] ?? [])..add(element['fileHash']));
          return previous;
        }));
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

  Future<bool> removeTask(dynamic id, {bool withGaller = false}) async {
    if (withGaller) {
      await deleteGallery(id);
    }
    _logger?.w('delelte task with $id');
    return excuteSqlAsync('delete from Tasks where id =?', [id]);
  }

  Future<bool> deleteGallery(dynamic id) async {
    _logger?.w('del gallery with id $id');
    return excuteSqlAsync('delete from Gallery where id =?', [id]).then(
        (value) =>
            excuteSqlAsync('delete from GalleryFile where gid =?', [id]));
  }

  Future<bool> deleteGalleryFile(dynamic id, String hash) async {
    return excuteSqlAsync(
        'delete from GalleryFile where gid =? and hash=?', [id, hash]);
  }
}
