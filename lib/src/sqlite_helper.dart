import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show QueryRow, Variable;
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';

import 'db/database.dart';
import 'multi_paltform.dart' show createDriftExecutor;

/// hitomi 的数据库门面。
///
/// 底层已重构为 drift（见 lib/src/db/）：
/// - [HitomiDatabase]：drift 表定义 + MigrationStrategy（schema v16）；
/// - `custom_functions.dart`：PRAGMA 与 vector_distance / title_fixed / hash_distance，
///   在 executor 的 setup 回调里、任何 DDL 之前执行；
/// - `legacy.dart`：逐字移植的 v0→v16 迁移链。
///
/// 本类保持旧 `SqliteHelper` 的全部公共 API 与行为语义（返回 sqlite3 的
/// `ResultSet`/`Row`，调用方零改动）：所有查询经 drift 的 `customSelect` /
/// `customStatement` 走同一连接、同一事务机制，结果再包装回 `ResultSet`。
class SqliteHelper {
  final String _dirPath;
  final String dbName;
  final Logger? _logger;

  /// 初始化 single-flight：并发调用共享同一个 Future，
  /// 保证同一个 db 文件只会被 open 一次（open 内含建表 / 迁移）。
  Completer<HitomiDatabase>? _initCompleter;

  SqliteHelper(
    this._dirPath, {
    this.dbName = 'user.db',
    Logger? logger = null,
  }) : _logger = logger;

  /// single-flight 初始化：打开 drift 执行器并触发建表 / 迁移。
  ///
  /// 修复点（沿用旧实现注释）：旧实现里 `__db` 只在 `await` **之后**才赋值，
  /// 每次操作都会调 `checkInit`，并发查询各自 open 一个连接并重复跑建表 / 迁移，
  /// 多连接并发 `ALTER RENAME` / `CREATE` / `DROP` 是 database disk image is
  /// malformed 的直接成因。这里并发调用共享同一个 Future。
  Future<void> checkInit() async {
    await _ensureOpen();
  }

  Future<HitomiDatabase> _ensureOpen() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<HitomiDatabase>();
    _initCompleter = completer;

    () async {
      HitomiDatabase? opened;
      try {
        final executor = await createDriftExecutor(
          _dirPath,
          dbName,
          logger: _logger,
        );
        opened = HitomiDatabase(executor, logger: _logger);
        // 触发 drift 的完整 open 流程：setup（PRAGMA + 自定义函数）→
        // 读 user_version → onCreate / onUpgrade → setSchemaVersion。
        await opened.customSelect('select 1;').getSingle();
        if (!completer.isCompleted) completer.complete(opened);
      } catch (e, stack) {
        // 失败后允许下次重试，同时关掉已打开的连接避免句柄泄漏。
        if (identical(_initCompleter, completer)) {
          _initCompleter = null;
        }
        try {
          await opened?.close();
        } catch (closeError) {
          _logger?.e('close db after init failure error $closeError');
        }
        if (!completer.isCompleted) completer.completeError(e, stack);
      }
    }();

    return completer.future;
  }

  Future<void> close() async {
    final completer = _initCompleter;
    if (completer == null) return;
    _initCompleter = null;
    try {
      final db = await completer.future;
      await db.close();
    } catch (e) {
      _logger?.e('close db error $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 通用执行原语
  // ---------------------------------------------------------------------------

  List<Variable> _vars(List<dynamic> params) {
    return [for (final p in params) Variable<Object>(p)];
  }

  /// 把 drift 的 [QueryRow] 列表包装回 sqlite3 的 [ResultSet]，
  /// 让调用方的 `row['x']` / 迭代 / `.length` 行为与旧实现完全一致。
  ///
  /// 列名取首行的 key 顺序；重复列名在 drift 的 Map 里已按 lastIndexOf
  /// 语义折叠为最后一个值，与 sqlite3 原生 ResultSet 的查找语义一致。
  ResultSet _resultSet(List<QueryRow> rows) {
    if (rows.isEmpty) return ResultSet(const [], null, const []);
    final columnNames = rows.first.data.keys.toList();
    final rawRows = [for (final r in rows) r.data.values.toList()];
    return ResultSet(columnNames, null, rawRows);
  }

  Future<ResultSet> querySql(
    String sql, [
    List<dynamic> params = const [],
  ]) async {
    final db = await _ensureOpen();
    final rows = await db.customSelect(sql, variables: _vars(params)).get();
    return _resultSet(rows);
  }

  Future<Stream<Row>> querySqlByCursor(
    String sql, [
    List<dynamic> params = const [],
  ]) async {
    // drift 的 customSelect 是一次性取回结果集；调用方都是把整个结果折叠 /
    // 遍历完的用法，直接物化成 Stream 语义等价。
    final set = await querySql(sql, params);
    return Stream<Row>.fromIterable(set);
  }

  Future<bool> excuteSqlAsync(String sql, List<dynamic> params) async {
    final db = await _ensureOpen();
    await db.customStatement(sql, params);
    return true;
  }

  Future<bool> excuteSqlMultiParams(
    String sql,
    List<List<dynamic>> params,
  ) async {
    if (params.isEmpty) return true;
    final db = await _ensureOpen();
    // 整批参数放进同一个事务：中途失败不会留下半批数据。
    await db.transaction(() async {
      for (final element in params) {
        await db.customStatement(sql, element);
      }
    });
    return true;
  }

  /// 在单个事务里执行 [action]，并发调用由 drift 的执行器串行化。
  ///
  /// 嵌套调用（[action] 内部又调 `transaction`）走 drift 的 savepoint：
  /// 内层失败只回滚到保存点，异常照常向外传播；外层若捕获则继续，
  /// 外层事务最终提交时包含所有已提交内层的改动。
  Future<T> transaction<T>(Future<T> Function() action) async {
    final db = await _ensureOpen();
    return db.transaction(action);
  }

  Future<Map<List<dynamic>, ResultSet>> selectSqlMultiResultAsync(
    String sql,
    List<List<dynamic>> params,
  ) async {
    final db = await _ensureOpen();
    final result = <List<dynamic>, ResultSet>{};
    for (final element in params) {
      try {
        final rows = await db.customSelect(sql, variables: _vars(element)).get();
        result[element] = _resultSet(rows);
      } catch (e) {
        _logger?.e('$sql error parmas $element $e');
        rethrow;
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // 业务 API（与旧实现逐一对应）
  // ---------------------------------------------------------------------------

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
