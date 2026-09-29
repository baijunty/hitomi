import 'package:drift/drift.dart';

/// Drift 表定义，与现网 v16 schema 逐列对齐。
///
/// 注意：
/// - build.yaml 里 `case_from_dart_to_sql: preserve`，列名按 Dart 名原样生成，
///   保证 `createDate` / `imageEmbedding` / `fileHash` 等驼峰列名不变。
/// - 每个表显式覆盖 [tableName]，避免 drift 默认的单数化改名规则。
/// - 数据类统一用 `XxxRow` 命名，避免与 `gallery/gallery.dart` 里的
///   `Gallery` 模型类冲突。
/// - 原 schema 中 `path TEXT Quique` 是笔误（并非 UNIQUE），这里保持为普通
///   可空 TEXT，**不要**添加真正的 UNIQUE 约束。

/// 标签表：type + name 唯一。
@DataClassName('TagRow')
class Tags extends Table {
  @override
  String get tableName => 'Tags';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get translate => text()();
  TextColumn get intro => text()();
  TextColumn get links => text().nullable()();
  TextColumn get superior => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{type, name}];
}

/// 画廊主表。
@DataClassName('GalleryRow')
class Gallery extends Table {
  @override
  String get tableName => 'Gallery';

  IntColumn get id => integer()();
  TextColumn get path => text().nullable()();
  TextColumn get language => text()();
  TextColumn get title => text()();
  TextColumn get createDate => text().nullable()();
  TextColumn get type => text().nullable()();
  IntColumn get date => integer().nullable()();
  IntColumn get mark => integer().withDefault(const Constant(0))();
  IntColumn get length => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 画廊扩展信息（向量嵌入 / 故事描述），与 Gallery 一对一。
@DataClassName('GalleryExtraRow')
class GalleryExtra extends Table {
  @override
  String get tableName => 'GalleryExtra';

  IntColumn get id => integer()();
  IntColumn get gid =>
      integer().references(Gallery, #id, onDelete: KeyAction.cascade)();
  BlobColumn get imageEmbedding => blob().nullable()();
  TextColumn get storyDescription => text().nullable()();
  BlobColumn get textEmbedding => blob().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{gid}];
}

/// 画廊文件清单，主键 (gid, name)。
@DataClassName('GalleryFileRow')
class GalleryFile extends Table {
  @override
  String get tableName => 'GalleryFile';

  IntColumn get gid =>
      integer().nullable().references(Gallery, #id, onDelete: KeyAction.cascade)();
  TextColumn get hash => text()();
  TextColumn get name => text()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get fileHash => integer().nullable()();

  @override
  Set<Column> get primaryKey => {gid, name};
}

/// 下载任务表。
@DataClassName('TaskRow')
class Tasks extends Table {
  @override
  String get tableName => 'Tasks';

  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get path => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 用户日志（书签 / 历史 / 广告屏蔽等，按 type 位掩码区分）。
@DataClassName('UserLogRow')
class UserLog extends Table {
  @override
  String get tableName => 'UserLog';

  IntColumn get id => integer()();
  IntColumn get value => integer().nullable()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  TextColumn get content => text().nullable()();
  IntColumn get date => integer().nullable()();
  BlobColumn get extension => blob().nullable()();

  @override
  Set<Column> get primaryKey => {id, type};
}

/// 画廊-标签多对多关联。
@DataClassName('GalleryTagRelationRow')
class GalleryTagRelation extends Table {
  @override
  String get tableName => 'GalleryTagRelation';

  IntColumn get gid =>
      integer().nullable().references(Gallery, #id, onDelete: KeyAction.cascade)();
  IntColumn get tid => integer().nullable().references(Tags, #id)();
  IntColumn get type => integer().nullable()();

  @override
  Set<Column> get primaryKey => {gid, tid};
}
