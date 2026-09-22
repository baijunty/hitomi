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
  static final _version = 16;
  Logger? _logger = null;
  late CommonDatabase _db;
  String dbName;

  /// 初始化 single-flight：并发调用共享同一个 Future，
  /// 保证同一个 db 文件只会被 open 一次。
  Completer<void>? _initCompleter;

  /// 写事务串行化队列的尾部，避免同一连接上两个逻辑事务交错 BEGIN / COMMIT。
  Future<void> _writeChain = Future.value();

  /// 当前是否已处于事务中，让嵌套调用直接加入外层事务而不是重复 BEGIN。
  bool _inTransaction = false;

  SqliteHelper(
    this._dirPath, {
    this.dbName = 'user.db',
    Logger? logger = null,
  }) {
    this._logger = logger;
  }

  /// single-flight 初始化。
  ///
  /// 修复点：旧实现里 `__db` 只在 `await` **之后**才赋值，而 `databaseOpera`
  /// 每次操作都会调 `checkInit`。启动时并发的多个查询全部看到 `__db == null`，
  /// 于是各自 open 一个连接到同一个文件，并且每个连接都再跑一遍建表 / 迁移 ——
  /// 多个连接并发执行 `ALTER TABLE ... RENAME` / `CREATE` / `DROP` 是
  /// database disk image is malformed 的直接成因。
  Future<void> checkInit() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    () async {
      CommonDatabase? opened;
      try {
        opened = await openSqliteDb(_dirPath, dbName);
        _db = opened;
        await init();
        if (!completer.isCompleted) completer.complete();
      } catch (e, stack) {
        // 失败后允许下次重试，同时关掉已打开的连接避免句柄泄漏。
        if (identical(_initCompleter, completer)) {
          _initCompleter = null;
        }
        try {
          opened?.close();
        } catch (closeError) {
          _logger?.e('close db after init failure error $closeError');
        }
        if (!completer.isCompleted) completer.completeError(e, stack);
      }
    }();

    return completer.future;
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

  /// 打开连接后、任何 DDL 之前先落地 PRAGMA。
  ///
  /// 修复点：旧实现把 `journal_mode = WAL` 放在建表和迁移**之后**，而且完全不看
  /// 返回值。一旦有别的连接还持有锁，切换会失败而代码毫无察觉，于是同一个 db
  /// 文件上部分连接在 WAL、部分还在 DELETE —— 混用 journal mode 会直接损坏数据库。
  void _applyPragmas(CommonDatabase db) {
    // 锁冲突时等待而不是立刻抛 SQLITE_BUSY（旧代码会把 BUSY 静默吞掉）。
    db.execute('PRAGMA busy_timeout=15000;');

    // WAL 必须在事务外切换，并且要确认真的切过去了。
    final before = _pragmaString(db, 'PRAGMA journal_mode;');
    if (before != 'wal') {
      try {
        final after = _pragmaString(db, 'PRAGMA journal_mode=WAL;');
        if (after != 'wal') {
          _logger?.e(
            'WAL 切换失败，当前 journal_mode=$after（切换前=$before）。'
            '若数据目录在网络盘 / FUSE 上，SQLite 可能拒绝启用 WAL。',
          );
        } else {
          _logger?.i('journal_mode 已切换为 WAL');
        }
      } catch (e) {
        _logger?.e('设置 journal_mode=WAL 失败 $e');
      }
    }

    // 限制回滚后 wal 文件的保留大小，避免无限膨胀诱导人工删除 -wal。
    db.execute('PRAGMA journal_size_limit=67108864;');
    // 让 schema 里声明的 ON DELETE CASCADE 真正生效（SQLite 默认是 OFF）。
    db.execute('PRAGMA foreign_keys=ON;');
  }

  String? _pragmaString(CommonDatabase db, String statement) {
    try {
      return db.select(statement).first.columnAt(0)?.toString().toLowerCase();
    } catch (e) {
      _logger?.e('exec "$statement" error $e');
      return null;
    }
  }

  /// 初始化 schema / 自定义函数 / 版本迁移。
  ///
  /// 修复点：旧签名是 `void init() async`，调用方写的是 `.then((v) => init())`，
  /// 回调返回 void 导致 Future 链**根本不会等待**迁移完成 —— schema 还没建好
  /// 查询就发出去了，迁移中途抛异常也只会变成 unhandled async error。
  Future<void> init() async {
    _applyPragmas(_db);
    createTables(_db);
    await createIndexes(_db);
    _registerFunctions(_db);

    final version = _readUserVersion(_db);
    if (version != _version) {
      // 迁移期间必须关闭外键：历史库是在 foreign_keys=OFF 下写出来的，
      // 可能存在孤儿行（例如 GalleryFile.gid 指向已不存在的 Gallery）。
      // 开着 FK 跑 `insert ... select` 会直接约束失败并回滚整个迁移。
      // 注意 PRAGMA foreign_keys 在事务内是 no-op，所以必须在事务外切换。
      _db.execute('PRAGMA foreign_keys=OFF;');
      try {
        await _migrateToTarget(_db, version);
      } finally {
        _db.execute('PRAGMA foreign_keys=ON;');
      }
    }
  }

  int _readUserVersion(CommonDatabase db) {
    final stmt = db.prepare('PRAGMA user_version;');
    try {
      return stmt.select().first.columnAt(0) as int;
    } finally {
      stmt.close();
    }
  }

  void _registerFunctions(CommonDatabase db) {
    db.createFunction(
      functionName: 'vector_distance',
      function: vectorDistance,
      argumentCount: AllowedArgumentCount.any(),
    );
    db.createFunction(
      functionName: 'title_fixed',
      function: pureTitle,
      argumentCount: AllowedArgumentCount(2),
    );
    db.createFunction(
      functionName: 'hash_distance',
      function: hashDistance,
      argumentCount: AllowedArgumentCount(2),
    );
  }

  /// 把整个迁移包在一个事务里。
  ///
  /// 旧实现每个 `DROP` / `ALTER RENAME` / `CREATE` / `INSERT...SELECT` 都是独立的
  /// autocommit 语句，中途被 kill 就会留下「Gallery 是空的、GalleryTemp 是唯一
  /// 副本、user_version 没更新」的半迁移状态，而重跑的第一句
  /// `drop table if exists ...Temp` 会直接删掉唯一的数据副本。
  Future<void> _migrateToTarget(CommonDatabase db, int startVersion) async {
    // 注意：这里走 _exclusive 而不是 public 的 transaction()，
    // 因为当前正处于 checkInit() 内部，再 await checkInit() 会自死锁。
    await _exclusive(
      () => _inTransactionBlock(() async {
        var version = startVersion;
        var steps = 0;
        while (version > 0 && version != _version) {
          // 旧实现里 dataBaseUpgrade 未命中 case 会 return oldVersion，
          // 于是 while 条件永远成立 —— 直接死循环。这里显式挡住。
          if (++steps > 64) {
            throw StateError('migration did not converge at version $version');
          }
          final next = version < _version
              ? dataBaseUpgrade(db, version)
              : dateBaseDowngrade(db, version);
          if (next == version) {
            throw StateError('migration made no progress at version $version');
          }
          version = next;
        }
        db.execute('PRAGMA user_version=$_version;');
        _logger?.i('database migrated $startVersion -> $_version');
      }),
    );
  }

  /// 把 [body] 排到写事务队列尾部串行执行。
  Future<T> _exclusive<T>(Future<T> Function() body) {
    final run = _writeChain.then((_) => body());
    // 无论成败都推进队列，避免一次失败把后续事务永久卡住。
    _writeChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Zone 标记：当前异步链是否已处于某个事务内部。
  static const _txZoneKey = #sqlite_transaction_active;

  /// 在单个事务里执行 [action]，并发调用按到达顺序串行化。
  ///
  /// 嵌套调用（[action] 内部又调 `transaction`）会直接加入当前事务，
  /// 不会重复 BEGIN。
  ///
  /// 注意：判断「是否嵌套」必须用 Zone 而不是 `_inTransaction`。
  /// 若嵌套调用也走 `_exclusive`，它会被排到外层事务的后面，而外层正
  /// `await` 着它的结果 —— 外层等嵌套、嵌套等外层，写链从此永久死锁
  /// （insertGallery → queryOrInsertTagTable / excuteSqlMultiParams
  /// 正是这种嵌套，导致所有下载任务卡死）。Zone 标记沿异步链传播，
  /// 能准确区分「嵌套在当前事务里」与「另一个并发事务」。
  Future<T> transaction<T>(Future<T> Function() action) async {
    await checkInit();
    if (Zone.current[_txZoneKey] == true) {
      // 嵌套在当前事务的异步链上：直接内联执行，加入外层 BEGIN。
      return action();
    }
    return _exclusive(
      () => Zone.current
          .fork(zoneValues: {_txZoneKey: true})
          .run(() => _inTransactionBlock(action)),
    );
  }

  Future<T> _inTransactionBlock<T>(Future<T> Function() action) async {
    if (_inTransaction) return action();

    _db.execute('BEGIN IMMEDIATE;');
    _inTransaction = true;
    var needsRollback = true;
    try {
      final result = await action();
      _db.execute('COMMIT;');
      needsRollback = false;
      return result;
    } catch (e) {
      if (needsRollback) {
        try {
          _db.execute('ROLLBACK;');
        } catch (rollbackError) {
          _logger?.e('rollback failed $rollbackError (original: $e)');
        }
      }
      rethrow;
    } finally {
      _inTransaction = false;
    }
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
      length integer
      )''');
    db.execute('''create table if not exists GalleryExtra(
      id integer PRIMARY KEY,
      gid integer not null,
      imageEmbedding BLOB,
      storyDescription TEXT,
      textEmbedding BLOB,
      FOREIGN KEY(gid) REFERENCES Gallery(id) ON DELETE CASCADE,
      UNIQUE(gid)
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
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gallery_language ON Gallery(language);',
    );
    db.execute('CREATE INDEX IF NOT EXISTS idx_gallery_date ON Gallery(date);');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gallery_tag ON GalleryTagRelation(tid);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gallery_gid ON GalleryTagRelation(gid);',
    );
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tags_type_name ON Tags(type, name);',
    );
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
          // 修复：其它 case 都有这句，这里漏掉了，导致 UserLogTemp 永久残留。
          db.execute("drop table if exists UserLogTemp ");
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
      case 15:
        {
          db.execute("drop table if exists GalleryTemp ");
          db.execute("ALTER table Gallery rename to GalleryTemp");
          createTables(db);
          db.execute(
            """insert into  Gallery(id,path,language,title,createDate,type,date,mark,length)
              select id,path,language,title,createDate,type,date,mark,length from GalleryTemp""",
          );
          db.execute("drop table if exists GalleryTemp ");
          return 16;
        }
    }
    return oldVersion;
  }

  /// 比当前代码更新的 schema 无法安全降级。
  ///
  /// 旧实现直接 `return _version`，随后照样写 `PRAGMA user_version=$_version`，
  /// 于是数据库**谎称**自己是 v$_version 而实际 schema 更新，后续 SQL 引用不存在
  /// 的列。这里改为明确拒绝 —— 宁可启动失败，也不要静默损坏。
  int dateBaseDowngrade(CommonDatabase db, int oldVersion) {
    throw StateError(
      'database schema version $oldVersion is newer than this build '
      '($_version); refusing to open to avoid a schema mismatch. '
      'Please use a newer binary.',
    );
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
    return transaction(() async {
      final sets = await selectSqlMultiResultAsync(
        'select id,type,name from Tags where type=? and name=?',
        params.map((e) => e.params).toList(),
      );

      final entries = <MapEntry<Label, int>>[];
      // 串行处理：lastInsertRowId 是**连接级**全局值，旧代码用 Future.wait 并发
      // 插入时 A 可能读到 B 刚插入的 id，导致 GalleryTagRelation 关联到错误的 tag。
      for (final e in sets.entries) {
        var id = e.value.firstOrNull?['id'] as int?;
        final label = fromString(e.key[0], e.key[1]);
        if (label is QueryText) {
          id = -1;
        } else if (id == null) {
          await excuteSqlAsync(
            'insert into Tags(type,name,translate,intro,links,superior) '
            'values(?,?,?,?,?,?) on conflict(type,name) do update set '
            'translate=excluded.translate,intro=excluded.intro,'
            'links=excluded.links,superior=excluded.superior',
            [e.key[0], e.key[1], e.key[1], e.key[1], null, null],
          );
          // 用确定性 SELECT 取回 id，不再依赖 lastInsertRowId。
          id = await querySql(
            'select id from Tags where type=? and name=?',
            [e.key[0], e.key[1]],
          ).then((set) => set.firstOrNull?['id'] as int?);
        }
        entries.add(MapEntry(label, id ?? -1));
      }
      return Map.fromEntries(entries);
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
    if (params.isEmpty) return true;
    // 整批参数放进同一个事务：中途失败不会留下半批数据。
    return transaction(() async {
      await databaseOpera(sql, (stmt) {
        for (final element in params) {
          stmt.execute(element);
        }
        return true;
      });
      return true;
    });
  }

  Future<bool> insertGallery(Gallery gallery, FileSystemEntity path) async {
    // 文件系统访问放在事务外，避免持写锁期间做 I/O。
    final modifiedAt = path.existsSync()
        ? path.statSync().modified.millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;

    // 三条语句（Gallery / GalleryTagRelation / GalleryExtra）放进同一个事务，
    // 中途失败会整体回滚，不会出现「主表有、关联表没有」的不一致。
    return transaction(() async {
      final idMap = await queryOrInsertTagTable(gallery.labels());
      await excuteSqlAsync(
        'replace into Gallery(id,path,language,title,createDate,type,date,mark,length) values(?,?,?,?,?,?,?,?,?)',
        [
          gallery.id,
          basename(path.path),
          gallery.language ?? '',
          gallery.name,
          gallery.date,
          gallery.type,
          modifiedAt,
          0,
          gallery.files.length,
        ],
      );
      await excuteSqlMultiParams(
        'replace into GalleryTagRelation(gid,tid) values (?,?)',
        // foreign_keys 已打开，QueryText 的占位 id = -1 会违反外键，过滤掉。
        idMap.values.where((e) => e > 0).map((e) => [gallery.id, e]).toList(),
      );
      await excuteSqlAsync('replace into GalleryExtra(gid) values(?)', [
        gallery.id,
      ]);
      return true;
    });
  }

  //通过id更新GalleryExtra的imageEmbedding
  Future<bool> updateGalleryImageEmbedding(int id, List<double> feature) async {
    var list = Float64List.fromList(feature);
    var buffer = list.buffer;
    return await excuteSqlAsync(
      'UPDATE GalleryExtra SET imageEmbedding = ? WHERE gid = ?',
      [buffer.asUint8List(), id],
    );
  }

  //通过id更新GalleryExtra的storyDescription
  Future<bool> updateGalleryStoryDescription(int id, String description) async {
    return await excuteSqlAsync(
      'UPDATE GalleryExtra SET storyDescription = ? WHERE gid = ?',
      [description, id],
    );
  }

  //通过id更新GalleryExtra的textEmbedding
  Future<bool> updateGalleryTextEmbedding(int id, List<double> feature) async {
    var list = Float64List.fromList(feature);
    var buffer = list.buffer;
    return await excuteSqlAsync(
      'UPDATE GalleryExtra SET textEmbedding = ? WHERE gid = ?',
      [buffer.asUint8List(), id],
    );
  }

  //通过gid查询GalleryExtra
  Future<Map<String, dynamic>?> queryGalleryExtraById(int gid) async {
    return querySql('select * from GalleryExtra where gid=?', [
      gid,
    ]).then((value) => value.firstOrNull as Map<String, dynamic>?);
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
    ).then((set) => set.map((r) => Image.fromRow(r)).toList()).catchError((e) {
      _logger?.e(
        "select * from GalleryFile where gid=$id order by name occus $e",
      );
      return <Image>[];
    }, test: (e) => true);
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
    _logger?.w('delete task with $id');
    return excuteSqlAsync('delete from Tasks where id =?', [id]);
  }

  Future<bool> deleteGallery(dynamic id) async {
    _logger?.w('del gallery with id $id');
    // 四条删除放进同一个事务，避免删一半被中断留下孤儿行。
    // 注意顺序：先删子表、最后删父表 Gallery。现网库里 GalleryTagRelation 的
    // 外键是旧版本建的、没有 ON DELETE CASCADE（create table if not exists
    // 不会更新已存在的表），先删 Gallery 会触发 FOREIGN KEY constraint failed。
    return transaction(() async {
      await excuteSqlAsync('delete from GalleryFile where gid =?', [id]);
      await excuteSqlAsync('delete from GalleryTagRelation where gid =?', [id]);
      await excuteSqlAsync('delete from GalleryExtra where gid =?', [id]);
      await excuteSqlAsync('delete from Gallery where id =?', [id]);
      return true;
    });
  }

  Future<bool> deleteGalleryFile(dynamic id, String name) async {
    return excuteSqlAsync('delete from GalleryFile where gid =? and name=?', [
      id,
      name,
    ]);
  }
}
