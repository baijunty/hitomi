import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:ml_linalg/distance.dart';
import 'package:ml_linalg/vector.dart';
import 'package:sqlite3/common.dart';

import '../dhash.dart';
import '../gallery_util.dart';

/// 连接建立后、任何 DDL / 查询之前必须执行的一次性设置。
///
/// drift 在 `NativeDatabase.opened(setup: ...)` / `WasmDatabase.opened(setup: ...)`
/// 里、读取 schema 版本**之前**调用它，所以 PRAGMA 和自定义函数对建表、
/// 迁移以及后续所有查询都生效。
void applyConnectionSetup(CommonDatabase db, {Logger? logger}) {
  _applyPragmas(db, logger);
  registerFunctions(db, logger: logger);
}

/// 打开连接后、任何 DDL 之前先落地 PRAGMA。
///
/// 修复点：旧实现把 `journal_mode = WAL` 放在建表和迁移**之后**，而且完全不看
/// 返回值。一旦有别的连接还持有锁，切换会失败而代码毫无察觉，于是同一个 db
/// 文件上部分连接在 WAL、部分还在 DELETE —— 混用 journal mode 会直接损坏数据库。
void _applyPragmas(CommonDatabase db, Logger? logger) {
  // 锁冲突时等待而不是立刻抛 SQLITE_BUSY（旧代码会把 BUSY 静默吞掉）。
  db.execute('PRAGMA busy_timeout=15000;');

  // WAL 必须在事务外切换，并且要确认真的切过去了。
  final before = _pragmaString(db, 'PRAGMA journal_mode;', logger);
  if (before != 'wal') {
    try {
      final after = _pragmaString(db, 'PRAGMA journal_mode=WAL;', logger);
      if (after != 'wal') {
        logger?.e(
          'WAL 切换失败，当前 journal_mode=$after（切换前=$before）。'
          '若数据目录在网络盘 / FUSE 上，SQLite 可能拒绝启用 WAL。',
        );
      } else {
        logger?.i('journal_mode 已切换为 WAL');
      }
    } catch (e) {
      logger?.e('设置 journal_mode=WAL 失败 $e');
    }
  }

  // 限制回滚后 wal 文件的保留大小，避免无限膨胀诱导人工删除 -wal。
  db.execute('PRAGMA journal_size_limit=67108864;');
  // 让 schema 里声明的 ON DELETE CASCADE 真正生效（SQLite 默认是 OFF）。
  db.execute('PRAGMA foreign_keys=ON;');
}

String? _pragmaString(CommonDatabase db, String statement, Logger? logger) {
  try {
    return db.select(statement).first.columnAt(0)?.toString().toLowerCase();
  } catch (e) {
    logger?.e('exec "$statement" error $e');
    return null;
  }
}

/// 注册 SQL 里用到的自定义函数：vector_distance / title_fixed / hash_distance。
void registerFunctions(CommonDatabase db, {Logger? logger}) {
  db.createFunction(
    functionName: 'vector_distance',
    function: (args) => vectorDistance(args, logger),
    argumentCount: AllowedArgumentCount.any(),
  );
  db.createFunction(
    functionName: 'title_fixed',
    function: (args) => pureTitle(args),
    argumentCount: AllowedArgumentCount(2),
  );
  db.createFunction(
    functionName: 'hash_distance',
    function: (args) => hashDistance(args),
    argumentCount: AllowedArgumentCount(2),
  );
}

double vectorDistance(List<Object?> arguments, Logger? logger) {
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
      logger?.e('args ${arguments.sublist(2)} occus $e');
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
