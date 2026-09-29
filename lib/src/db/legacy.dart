import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

/// 目标 schema 版本（对应 PRAGMA user_version）。
const int kSchemaVersion = 16;

/// 把整个 v0→v16 迁移链包在一个事务里跑，逐句对齐旧 `SqliteHelper._migrateToTarget`。
///
/// 在 drift 的 `beforeOpen` 里调用：此时 [DatabaseConnectionUser] 是
/// `BeforeOpenRunner`，`transaction()` 会走 NativeDatabase 的
/// `BEGIN IMMEDIATE` / `COMMIT`，与旧实现一致。
///
/// 修复点（沿用旧实现注释）：旧实现每个 `DROP` / `ALTER RENAME` / `CREATE` /
/// `INSERT...SELECT` 都是独立 autocommit 语句，中途被 kill 会留下「Gallery 是空的、
/// GalleryTemp 是唯一副本、user_version 没更新」的半迁移状态，而重跑的第一句
/// `drop table if exists ...Temp` 会直接删掉唯一的数据副本。
///
/// 迁移期间必须关闭外键：历史库是在 foreign_keys=OFF 下写出来的，可能存在孤儿行
/// （例如 GalleryFile.gid 指向已不存在的 Gallery）。开着 FK 跑 `insert ... select`
/// 会直接约束失败并回滚整个迁移。注意 PRAGMA foreign_keys 在事务内是 no-op，
/// 所以必须在事务外切换。
Future<void> runLegacyUpgradeChain(
  DatabaseConnectionUser db,
  int startVersion, {
  Logger? logger,
}) async {
  // 比当前代码更新的 schema 无法安全降级：旧实现直接 return 后照样写
  // user_version，于是数据库谎称自己是 v16 而实际 schema 更新，后续 SQL 引用
  // 不存在的列。这里明确拒绝 —— 宁可启动失败，也不要静默损坏。
  if (startVersion > kSchemaVersion) {
    throw StateError(
      'database schema version $startVersion is newer than this build '
      '($kSchemaVersion); refusing to open to avoid a schema mismatch. '
      'Please use a newer binary.',
    );
  }
  await db.customStatement('PRAGMA foreign_keys=OFF;');
  try {
    await db.transaction(() async {
      var version = startVersion;
      var steps = 0;
      while (version > 0 && version != kSchemaVersion) {
        if (++steps > 64) {
          throw StateError('migration did not converge at version $version');
        }
        final next = await dataBaseUpgrade(db, version);
        if (next == version) {
          throw StateError('migration made no progress at version $version');
        }
        version = next;
      }
      await db.customStatement('PRAGMA user_version=$kSchemaVersion;');
      logger?.i('database migrated $startVersion -> $kSchemaVersion');
    });
  } finally {
    await db.customStatement('PRAGMA foreign_keys=ON;');
  }
}

/// v16 建表 DDL，逐字保留自旧 `SqliteHelper.createTables`。
///
/// 迁移链里的 rename-dance 需要「按 v16 重建目标表」，这里用原始 SQL 而不是
/// drift 生成的 DDL，保证与现网行为一致（含 `TEXT Quique` 这类历史笔误）。
Future<void> createTablesV16(DatabaseConnectionUser db) async {
  await db.customStatement('''create table  if not exists Tags(
    id Integer PRIMARY KEY autoincrement,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    translate TEXT NOT NULL,
    intro TEXT NOT NULL,
    links TEXT,
    superior TEXT,
    CONSTRAINT tag UNIQUE (type,name)
    )''');
  await db.customStatement('''create table if not exists Gallery(
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
  await db.customStatement('''create table if not exists GalleryExtra(
    id integer PRIMARY KEY,
    gid integer not null,
    imageEmbedding BLOB,
    storyDescription TEXT,
    textEmbedding BLOB,
    FOREIGN KEY(gid) REFERENCES Gallery(id) ON DELETE CASCADE,
    UNIQUE(gid)
    )''');
  await db.customStatement('''create table if not exists GalleryFile(
    gid INTEGER,
    hash TEXT not NULL,
    name TEXT not NULL,
    width integer,
    height integer,
    fileHash integer,
    PRIMARY KEY(gid,name),
    FOREIGN KEY(gid) REFERENCES Gallery(id)  ON DELETE CASCADE
    )''');
  await db.customStatement('''create table if not exists Tasks(
    id integer PRIMARY KEY,
    title Text not null,
    path TEXT not null,
    completed bool default 0
    )''');
  await db.customStatement('''create table if not exists UserLog(
    id integer,
    value integer,
    type integer default 0,
    content Text,
    date integer,
    extension BLOB,
    PRIMARY KEY(id,type)
    )''');
  await db.customStatement('''create table if not exists GalleryTagRelation(
    gid integer,
    tid integer,
    type integer default null,
    FOREIGN KEY (gid) REFERENCES Gallery(id) ON DELETE CASCADE,
    FOREIGN KEY (tid) REFERENCES Tags(id),
    PRIMARY KEY (gid, tid)
    )''');
}

/// 旧 `SqliteHelper.dataBaseUpgrade` 的逐字移植（v0 → v16）。
///
/// 返回迁移后的版本号；未命中任何 case 时返回原版本（调用方会据此报错）。
Future<int> dataBaseUpgrade(DatabaseConnectionUser db, int oldVersion) async {
  switch (oldVersion) {
    case 0:
    case 1:
    case 2:
    case 3:
      {
        await db.customStatement("drop table if exists  GalleryTemp ");
        await db.customStatement("ALTER table Gallery rename to GalleryTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Gallery(id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length) select id,path,author,groupes,serial,null,language,title,null,null,0,0,0 from GalleryTemp""",
        );
        await db.customStatement("drop table GalleryTemp");
        return 4;
      }
    case 4:
      {
        await db.customStatement("drop table if exists  GalleryTemp ");
        await db.customStatement("ALTER table Gallery rename to GalleryTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,date,mark,length) select id,path,author,groupes,serial,character,language,title,tags,createDate,date,mark,length from GalleryTemp""",
        );
        await db.customStatement("drop table GalleryTemp");
        return 5;
      }
    case 5:
      {
        await db.customStatement("drop table if exists  GalleryTemp ");
        await db.customStatement("ALTER table Gallery rename to GalleryTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length) select id,path,artist,groupes,series,character,language,title,tag,createDate,null,date,mark,length from GalleryTemp""",
        );
        await db.customStatement("drop table GalleryTemp");
        return 6;
      }
    case 6:
      {
        await db.customStatement("drop table if exists TagsTemp ");
        await db.customStatement("ALTER table Tags rename to TagsTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Tags(id,type,name,translate,intro,links,superior) select id,type,name,translate,intro,null,null from TagsTemp""",
        );
        await db.customStatement("drop table TagsTemp");
        return 7;
      }
    case 7:
      {
        await db.customStatement("drop table if exists UserLogTemp ");
        await db.customStatement("ALTER table UserLog rename to UserLogTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  UserLog(id,mark,type,content,extension) select id,mark,0,content,extension from UserLogTemp""",
        );
        await db.customStatement("drop table UserLogTemp");
        return 8;
      }
    case 8:
      {
        await db.customStatement("drop table if exists GalleryFileTemp ");
        await db.customStatement("ALTER table GalleryFile rename to GalleryFileTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into GalleryFile(gid,hash,name,width,height,fileHash,tag) select gid,hash,name,width,height,fileHash,null from GalleryFileTemp""",
        );
        await db.customStatement("drop table GalleryFileTemp");
        return 9;
      }
    case 9:
      {
        await db.customStatement("drop table if exists GalleryTemp ");
        await db.customStatement("ALTER table Gallery rename to GalleryTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,feature)
            select id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,null from GalleryTemp""",
        );
        await db.customStatement("drop table GalleryTemp");
        return 10;
      }
    case 10:
      {
        await db.customStatement("drop table if exists GalleryFileTemp ");
        await db.customStatement("ALTER table GalleryFile rename to GalleryFileTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into GalleryFile(gid,hash,name,width,height,fileHash) select gid,hash,name,width,height,fileHash from GalleryFileTemp""",
        );
        await db.customStatement("drop table GalleryFileTemp");
        return 11;
      }
    case 11:
      {
        await db.customStatement("drop table if exists GalleryTemp ");
        await db.customStatement("ALTER table Gallery rename to GalleryTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Gallery(id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,feature)
            select id,path,artist,groupes,series,character,language,title,tag,createDate,type,date,mark,length,null from GalleryTemp""",
        );
        final rows = await db
            .customSelect('select id,feature from GalleryTemp')
            .get();
        for (final row in rows) {
          final id = row.data['id'] as int;
          final feature = row.data['feature'] as String?;
          if (feature != null && feature.isNotEmpty) {
            final data = json.decode(feature) as List<dynamic>;
            final list = Float64List.fromList(
              data.map((element) => element as double).toList(),
            );
            await db.customStatement(
              "update Gallery set feature = ? where id = ?",
              [list.buffer.asUint8List(), id],
            );
          }
        }
        await db.customStatement("drop table if exists GalleryTemp ");
        return 12;
      }
    case 12:
      {
        await db.customStatement("drop table if exists GalleryTemp ");
        await db.customStatement("ALTER table Gallery rename to GalleryTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Gallery(id,path,language,title,createDate,type,date,mark,length,feature)
            select id,path,language,title,createDate,type,date,mark,length,feature from GalleryTemp""",
        );
        await db.customStatement("drop table if exists GalleryTemp ");
        return 13;
      }
    case 13:
      {
        await db.customStatement("drop table if exists UserLogTemp ");
        await db.customStatement("ALTER table UserLog rename to UserLogTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  UserLog(id,type,value,content,date,extension)
            select id,type,mark,content,null,null  from UserLogTemp""",
        );
        // 修复：其它 case 都有这句，旧实现漏掉导致 UserLogTemp 永久残留。
        await db.customStatement("drop table if exists UserLogTemp ");
        return 14;
      }
    case 14:
      {
        await db.customStatement("drop table if exists GalleryFileTemp ");
        await db.customStatement("ALTER table GalleryFile rename to GalleryFileTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into GalleryFile(gid,hash,name,width,height,fileHash) select gid,hash,name,width,height,fileHash from GalleryFileTemp""",
        );
        await db.customStatement("drop table GalleryFileTemp");
        return 15;
      }
    case 15:
      {
        await db.customStatement("drop table if exists GalleryTemp ");
        await db.customStatement("ALTER table Gallery rename to GalleryTemp");
        await createTablesV16(db);
        await db.customStatement(
          """insert into  Gallery(id,path,language,title,createDate,type,date,mark,length)
            select id,path,language,title,createDate,type,date,mark,length from GalleryTemp""",
        );
        await db.customStatement("drop table if exists GalleryTemp ");
        return 16;
      }
  }
  return oldVersion;
}
