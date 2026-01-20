import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:logger/logger.dart';
import 'package:ml_linalg/distance.dart';
import 'package:ml_linalg/vector.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';
import 'multi_paltform.dart' show openSqliteDb;

class SqliteHelper {
  final String _dirPath;
  static final _version = 15;
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
      await openSqliteDb(_dirPath, dbName)
          .then((value) {
            __db = value;
            _db = value;
          })
          .then((value) => init());
    }
  }

  double vectorDistance(List<Object?> arguments) {
    if (arguments.length == 2 && arguments.every((args) => args != null)) {
      try {
        var v1 = Vector.fromList(
          _uint8ListToDoubleList(arguments[0] as List<int>),
        );
        var v2 = Vector.fromList(
          _uint8ListToDoubleList(arguments[1] as List<int>),
        );
        return v1.distanceTo(v2, distance: Distance.cosine);
      } catch (e) {
        _logger?.e('args ${arguments.sublist(2)} occus $e');
        return 100.0;
      }
    }
    return 100.0;
  }

  List<double> _uint8ListToDoubleList(List<int> list) {
    Uint8List data = Uint8List.fromList(list);
    Float64List doubleArray = Float64List.view(data.buffer);
    return doubleArray.toList();
  }

  String? pureTitle(List<Object?> title) {
    return titleFixed(title[0].toString());
  }

  int hashDistance(List<Object?> arguments) {
    if (arguments.length == 2 && arguments.every((element) => element is int)) {
      return compareHashDistance(arguments[0] as int, arguments[1] as int);
    }
    return 64;
  }

  void init() async {
    __db = _db;
    createTables(_db);
    createIndexes(_db);
    final stmt = _db.prepare('PRAGMA user_version;');
    _db.createFunction(
      functionName: 'vector_distance',
      function: vectorDistance,
      argumentCount: AllowedArgumentCount.any(),
    );
    _db.createFunction(
      functionName: 'title_fixed',
      function: pureTitle,
      argumentCount: AllowedArgumentCount(2),
    );
    _db.createFunction(
      functionName: 'hash_distance',
      function: hashDistance,
      argumentCount: AllowedArgumentCount(2),
    );
    final result = stmt.select();
    var version = result.first.columnAt(0) as int;
    while (version > 0 && version != _version) {
      if (version < _version) {
        version = dataBaseUpgrade(_db, version);
      } else if (version > _version) {
        version = dateBaseDowngrade(_db, version);
      }
    }
    if (result.first.columnAt(0) != _version) {
      _db.execute('PRAGMA user_version=$_version;');
    }
    _db.execute('PRAGMA journal_mode = WAL;');
  }

  Future<T> databaseOpera<T>(
    String sql,
    T operate(CommonPreparedStatement statement), {
    bool releaseOnce = true,
  }) async {
    CommonPreparedStatement? stam;
    try {
      await checkInit();
      stam = _db.prepare(sql);
      return operate(stam);
    } catch (e, stack) {
      _logger?.e('excel sql $e faild ${stack}');
      return Future.error('$sql error', stack);
    } finally {
      if (releaseOnce) {
        stam?.close();
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
      language TEXT not null,
      title TEXT not NULL,
      createDate TEXT,
      type Text,
      date INTEGER,
      mark INTEGER default 0,
      length integer,
      feature BLOB
      )''');
    db.execute('''create table if not exists GalleryFile(
      gid INTEGER,
      hash TEXT not NULL,
      name TEXT not NULL,
      width integer,
      height integer,
      fileHash integer,
      PRIMARY KEY(gid,name),
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
      value integer,
      type integer default 0,
      content Text,
      date integer,
      extension BLOB,
      PRIMARY KEY(id,type)
      )''');
    db.execute('''create table if not exists GalleryTagRelation(
      gid integer,
      tid integer,
      type integer default null,
      FOREIGN KEY (gid) REFERENCES Gallery(id) ON DELETE CASCADE,
      FOREIGN KEY (tid) REFERENCES Tags(id),
      PRIMARY KEY (gid, tid)
      )''');
  }

  Future<void> createIndexes(CommonDatabase db) async {
    db.execute('CREATE INDEX IF NOT EXISTS idx_gallery_path ON Gallery(path);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_gallery_language ON Gallery(language);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_gallery_date ON Gallery(date);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_gallery_tag ON GalleryTagRelation(tid);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_gallery_gid ON GalleryTagRelation(gid);');
    db.execute('CREATE INDEX IF NOT EXISTS idx_tags_type_name ON Tags(type, name);');
  }

  Future<bool> insertUserLog(
    int id,
    int type, {
    int value = 0,
    String? content,
    int? date,
    List<int> extension = const [],
  }) async {
    return excuteSqlAsync(
      'replace into UserLog(id,value,type,content,date,extension) values (?,?,?,?,?,?)',
      [
        id,
        value,
        type,
        content,
        date ?? DateTime.now().millisecondsSinceEpoch,
        extension,
      ],
    );
  }

  Future<T?> readlData<T>(
    String tableNmae,
    String name,
    Map<String, dynamic> params,
  ) async {
    var where = params.entries.fold(
      StringBuffer(),
      (acc, element) => acc..write('${element.key}=? and '),
    );
    return querySql(
      'select $name from $tableNmae where $where 1=1',
      params.values.toList(),
    ).then((value) => value.firstOrNull?['$name'] as T?);
  }

  Future<bool> delete(String tableNmae, Map<String, dynamic> params) async {
    var where = params.entries.fold(
      StringBuffer(),
      (acc, element) => acc..write('${element.key}=? and '),
    );
    return excuteSqlAsync(
      'delete from $tableNmae where $where 1=1',
      params.values.toList(),
    );
  }

  int dataBaseUpgrade(CommonDatabase db, int oldVersion) {
    switch (oldVersion) {
      case 0:
      case 1:
      case 2:
      case 3:
        {
          db.execute("drop table if exists  GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
            """insert into  Gallery(id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length) select id,path,author,groupes,serial,null,language,title,null,null,0,0,0 from GalleryTemp""",
          );
          db.execute("drop table GalleryTemp");
          return 4;
        }
      case 4:
        {
          db.execute("drop table if exists  GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
            """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,date,mark,length) select id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length from GalleryTemp""",
          );
          db.execute("drop table GalleryTemp");
          return 5;
        }
      case 5:
        {
          db.execute("drop table if exists  GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
            """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length) select id,path,artist,groupes,series,character,language,title,tag,createDate,null,date,mark,length from GalleryTemp""",
          );
          db.execute("drop table GalleryTemp");
          return 6;
        }
      case 6:
        {
          db.execute("drop table if exists TagsTemp ");
          db.execute("ALTER table Tags rename to TagsTemp");
          createTables(db);
          db.execute(
            """insert into  Tags(id,type,name,translate,intro,links,superior) select id,type,name,translate,intro,null,null from TagsTemp""",
          );
          db.execute("drop table TagsTemp");
          return 7;
        }
      case 7:
        {
          db.execute("drop table if exists UserLogTemp ");
          db.execute("ALTER table UserLog rename to UserLogTemp");
          createTables(db);
          db.execute(
            """insert into  UserLog(id,mark,type,content,extension) select id,mark,0,content,extension from UserLogTemp""",
          );
          db.execute("drop table UserLogTemp");
          return 8;
        }
      case 8:
        {
          db.execute("drop table if exists GalleryFileTemp ");
          db.execute("ALTER table GalleryFile rename to GalleryFileTemp");
          createTables(db);
          db.execute(
            """insert into GalleryFile(gid,hash,name,width,height,fileHash,tag) select gid,hash,name,width,height,fileHash,null from GalleryFileTemp""",
          );
          db.execute("drop table GalleryFileTemp");
          return 9;
        }
      case 9:
        {
          db.execute("drop table if exists GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
            """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,feature) 
              select id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,null from GalleryTemp""",
          );
          db.execute("drop table GalleryTemp");
          return 10;
        }
      case 10:
        {
          db.execute("drop table if exists GalleryFileTemp ");
          db.execute("ALTER table GalleryFile rename to GalleryFileTemp");
          createTables(db);
          db.execute(
            """insert into GalleryFile(gid,hash,name,width,height,fileHash) select gid,hash,name,width,height,fileHash from GalleryFileTemp""",
          );
          db.execute("drop table GalleryFileTemp");
          return 11;
        }
      case 11:
        {
          db.execute("drop table if exists GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
            """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,feature) 
              select id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,null from GalleryTemp""",
          );
          var stmt = db.prepare('select id,feature from GalleryTemp');
          var cursor = stmt.selectCursor();
          while (cursor.moveNext()) {
            var row = cursor.current;
            var id = row[0] as int;
            var feature = row[1] as String?;
            if (feature != null && feature.isNotEmpty) {
              var data = json.decode(feature) as List<dynamic>;
              var list = Float64List.fromList(
                data.map((element) => element as double).toList(),
              );
              db.execute("update Gallery set feature = ? where id = ?", [
                list.buffer.asUint8List(),
                id,
              ]);
            }
          }
          stmt.close();
          db.execute("drop table if exists GalleryTemp ");
          return 12;
        }
      case 12:
        {
          db.execute("drop table if exists GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
            """insert into  Gallery(id,path,language,title,createDate,type,date,mark,length,feature) 
              select id,path,language,title,createDate,type,date,mark,length,feature from GalleryTemp""",
          );
          db.execute("drop table if exists GalleryTemp ");
          return 13;
        }
      case 13:
        {
          db.execute("drop table if exists UserLogTemp ");
          db.execute("ALTER table UserLog rename to UserLogTemp");
          createTables(db);
          db.execute(
            """insert into  UserLog(id,type,value,content,date,extension) 
              select id,type,mark,content,null,null  from UserLogTemp""",
          );
          return 14;
        }
      case 14:
        {
          db.execute("drop table if exists GalleryFileTemp ");
          db.execute("ALTER table GalleryFile rename to GalleryFileTemp");
          createTables(db);
          db.execute(
            """insert into GalleryFile(gid,hash,name,width,height,fileHash) select gid,hash,name,width,height,fileHash from GalleryFileTemp""",
          );
          db.execute("drop table GalleryFileTemp");
          return 15;
        }
    }
    return oldVersion;
  }

  int dateBaseDowngrade(CommonDatabase db, int oldVersion) {
    return _version;
  }

  Future<Map<List<dynamic>, ResultSet>> selectSqlMultiResultAsync(
    String sql,
    List<List<dynamic>> params,
  ) async {
    var r = databaseOpera(sql, (stmt) {
      return params.fold(<List<dynamic>, ResultSet>{}, (
        previousValue,
        element,
      ) {
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

  Future<Map<Label, int>> queryOrInsertTagTable(List<Label> params) async {
    return await selectSqlMultiResultAsync(
      'select id,type,name from Tags where type=? and name=?',
      params.map((e) => e.params).toList(),
    ).then((sets) async {
      return await Future.wait(
        sets.entries.map((e) async {
          var id = e.value.firstOrNull?['id'] as int?;
          var label = fromString(e.key[0], e.key[1]);
          if (label is QueryText) {
            id = -1;
          } else if (id == null) {
            await updateTagTable([
              [null, e.key[0], e.key[1], e.key[1], e.key[1], null, null],
            ]);
            id = this._db.lastInsertRowId;
          }
          return MapEntry(label, id);
        }),
      ).then((entries) => Map.fromEntries(entries));
    });
  }

  Future<bool> updateTagTable(List<List<dynamic>> params) async {
    return excuteSqlMultiParams(
      'REPLACE INTO Tags(id,type,name,translate,intro,links,superior) values(?,?,?,?,?,?,?) on Conflict(type,name) DO UPDATE SET translate=excluded.translate,intro=excluded.intro,links=excluded.links,superior=excluded.superior',
      params,
    );
  }

  Future<List<Map<String, dynamic>>> fetchLabelsFromSql(String name) async {
    // 先查询所有匹配的type
    var types = await querySql(
      'select distinct type from Tags where name like ? or translate like ?',
      ['%${name.toLowerCase()}%', '%${name.toLowerCase()}%'],
    );

    List<Map<String, dynamic>> result = [];
    // 对每种type，最多取20个结果，完全匹配的优先
    for (var type in types) {
      var sets = await querySql(
        '''select type, name, translate, intro, links 
             from Tags 
             where (name like ? or translate like ?) and type = ? 
             order by case when name = ? then 0 else 1 end, 
                      case when translate = ? then 0 else 1 end
             limit 20''',
        [
          '%${name.toLowerCase()}%',
          '%${name.toLowerCase()}%',
          type['type'],
          name,
          name,
        ],
      );
      result.addAll(sets.toList());
    }
    return result;
  }

  Future<ResultSet> querySql(
    String sql, [
    List<dynamic> params = const [],
  ]) async {
    return databaseOpera(sql, (stmt) => stmt.select(params));
  }

  Future<Stream<Row>> querySqlByCursor(
    String sql, [
    List<dynamic> params = const [],
  ]) async {
    return databaseOpera(
      sql,
      (stmt) => stmt.selectCursor(params).asStream(stmt),
      releaseOnce: false,
    );
  }

  Future<List<Label>> mapToLabel(List<String> names) async {
    var set = await selectSqlMultiResultAsync(
      'select * from Tags where name = ?',
      names.map((e) => [e]).toList(),
    );
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
    String sql,
    List<List<dynamic>> params,
  ) async {
    await databaseOpera(
      sql,
      (stmt) => params.forEach((element) {
        stmt.execute(element);
      }),
    );
    return true;
  }

  Future<bool> insertGallery(Gallery gallery, FileSystemEntity path) async {
    var idMap = await queryOrInsertTagTable(gallery.labels());
    return await excuteSqlAsync(
      'replace into Gallery(id,path,language,title,createDate,type,date,mark,length,feature) values(?,?,?,?,?,?,?,?,?,?)',
      [
        gallery.id,
        basename(path.path),
        gallery.language ?? '',
        gallery.name,
        gallery.date,
        gallery.type,
        path.existsSync()
            ? path.statSync().modified.millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch,
        0,
        gallery.files.length,
        null,
      ],
    ).then(
      (b) => excuteSqlMultiParams(
        'replace into GalleryTagRelation(gid,tid) values (?,?)',
        idMap.values.map((e) => [gallery.id, e]).toList(),
      ),
    );
  }

  //通过id更新Gallery表的feature
  Future<bool> updateGalleryFeatureById(int id, List<double> feature) async {
    var list = Float64List.fromList(feature);
    var buffer = list.buffer;
    return await excuteSqlAsync('UPDATE Gallery SET feature = ? WHERE id = ?', [
      buffer.asUint8List(),
      id,
    ]);
  }

  Future<ResultSet> queryGalleryByLabel(String type, Label label) async {
    return querySql(
      'select g.* from Gallery g where exists (select 1 from GalleryTagRelation r where r.gid = g.id and r.tid = (select id from Tags where type = ? and name = ?))',
      [type, label.name],
    );
  }

  Future<Gallery> queryGalleryById(dynamic id) async {
    var images = await queryImageHashsById(id);
    var row = await querySql(
      '''select * from Gallery where id=?''',
      [id],
    ).then((value) => value.first);
    if (row['length'] != images.length &&
        File(join(_dirPath, row['path'])).existsSync()) {
      return readGalleryFromPath(join(_dirPath, row['path']), _logger);
    }
    var tags = await querySql(
      'select t.type,t.name from Tags t where exists (select 1 from GalleryTagRelation r where r.tid = t.id and r.gid = ?)',
      [id],
    ).then((set) => set.map((r) => fromString(r['type'], r['name'])).toList());
    return Gallery.fromRow(row, tags, images);
  }

  Future<List<Image>> queryImageHashsById(dynamic id) async {
    return querySql(
      '''select * from GalleryFile where gid=? order by name''',
      [id],
    ).then((set) => set.map((r) => Image.fromRow(r)).toList());
  }

  //通过gid查询GalleryFile表并转换为Image List后返回
  Future<List<Image>> getImageListByGid(int gid) async {
    return querySql(
      '''
        select * from GalleryFile where gid=? order by name
    ''',
      [gid],
    ).then((set) => set.map((r) => Image.fromRow(r)).toList());
  }

  Future<Map<int, List<int>>> queryImageHashsByLabel(String type, String name) {
    return querySqlByCursor(
      '''select gf.gid,gf.fileHash,gf.name,g.path,g.length from Gallery g left join GalleryFile gf on g.id=gf.gid 
        where exists (select 1 from GalleryTagRelation r where r.gid = g.id and r.tid = (select id from Tags where type = ? and name = ?)) and gf.gid is not null order by gf.gid,gf.name''',
      [type, name],
    ).then(
      (value) => value.where((row) => row['fileHash'] != null).fold(
        <int, List<int>>{},
        (previous, element) {
          previous[element['gid']] = ((previous[element['gid']] ?? [])
            ..add(element['fileHash']));
          return previous;
        },
      ),
    );
  }

  Future<bool> insertGalleryFile(
    Gallery gallery,
    Image image,
    int? hash,
  ) async {
    return excuteSqlAsync(
      'replace into GalleryFile(gid,hash,name,width,height,fileHash) values(?,?,?,?,?,?)',
      [gallery.id, image.hash, image.name, image.width, image.height, hash],
    );
  }

  Future<void> updateTask(
    dynamic id,
    String title,
    String path,
    bool complete,
  ) async {
    await excuteSqlAsync(
      'replace into Tasks(id,title,path,completed) values(?,?,?,?)',
      [id, title, path, complete],
    );
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
    return excuteSqlAsync('delete from Gallery where id =?', [id])
        .then(
          (value) =>
              excuteSqlAsync('delete from GalleryFile where gid =?', [id]),
        )
        .then(
          (value) => excuteSqlAsync(
            'delete from GalleryTagRelation where gid =?',
            [id],
          ),
        );
  }

  Future<bool> deleteGalleryFile(dynamic id, String name) async {
    return excuteSqlAsync('delete from GalleryFile where gid =? and name=?', [
      id,
      name,
    ]);
  }
}
