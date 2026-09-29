import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import 'legacy.dart';
import 'tables.dart';

part 'database.g.dart';

/// hitomi 的 drift 数据库。
///
/// schema 版本直接复用现网的 `PRAGMA user_version`（目标 16），所以
/// `enableMigrations: true` 下：
/// - 全新库 → [onCreate] 用 drift 生成的 DDL 建表 + 建索引；
/// - 老库（user_version < 16）→ [onUpgrade] 跑逐字移植的 v0→v16 迁移链；
/// - 已是 16 的库 → 什么都不做，直接可用。
///
/// PRAGMA 与自定义函数（vector_distance / title_fixed / hash_distance）不在这里
/// 注册，而是在 executor 的 `setup` 回调里（见 custom_functions.dart 与各平台
/// 的 createDriftExecutor），drift 保证它在读取 schema 版本、跑迁移之前执行。
@DriftDatabase(
  tables: [
    Tags,
    Gallery,
    GalleryExtra,
    GalleryFile,
    Tasks,
    UserLog,
    GalleryTagRelation,
  ],
)
class HitomiDatabase extends _$HitomiDatabase {
  HitomiDatabase(super.executor, {Logger? logger}) : _logger = logger;

  final Logger? _logger;

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _createIndexes();
      },
      onUpgrade: (m, from, to) async {
        // 逐字移植的旧迁移链（rename-dance + 按 v16 重建 + 拷贝数据）。
        await runLegacyUpgradeChain(this, from, logger: _logger);
      },
    );
  }

  /// 6 个索引，逐字保留自旧 `SqliteHelper.createIndexes`。
  ///
  /// 用原始 SQL 而不是 `@TableIndex` 注解：drift 2.35 的 `@TableIndex` 不是
  /// `@Repeatable`，一个类上挂多个会直接编译失败，而这里 Gallery 需要 3 个、
  /// GalleryTagRelation 需要 2 个。
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_gallery_path ON Gallery(path);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_gallery_language ON Gallery(language);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_gallery_date ON Gallery(date);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_gallery_tag ON GalleryTagRelation(tid);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_gallery_gid ON GalleryTagRelation(gid);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tags_type_name ON Tags(type, name);',
    );
  }
}
