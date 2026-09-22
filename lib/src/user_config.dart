import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';
part 'user_config.freezed.dart';
part 'user_config.g.dart';

@immutable
@freezed
abstract class UserConfig with _$UserConfig {
  factory UserConfig(
    String output, {
    /// user.db（以及 WAL 模式下的 `-wal` / `-shm`）实际所在目录。
    ///
    /// 留空时回落到 `output`，保持旧行为。
    ///
    /// 之所以要能单独配：漫画数据盘常常是 NTFS / 网络盘，而 WAL 模式要求主库、
    /// `-wal`、`-shm` 三个文件都落在支持可靠 mmap + POSIX 锁的本地盘上。
    /// 只把 `user.db` 单独 bind mount 走是没用的 —— 近期写入全在 `-wal` 里。
    @Default("") String dbDir,
    @Default(5) int maxTasks,
    @Default(["japanese", "chinese"]) List<String> languages,
    @Default("") String proxy,
    @Default([]) List<List<FilterLabel>> excludes,
    @Default("2013-01-01") String dateLimit,
    @Default("12345678") String auth,
    @Default("debug") String logLevel,
    @Default("") String logOutput,
    @Default("127.0.0.1:7890") String remoteHttp,
    @Default(0.72) double threshold,
    @Default("http://localhost:8080") String llamaBaseUri,
    @Default("") String llamaApiKey,
    @Default("Embedding") String embeddingModel,
    @Default("gemma4-it:e2b") String multimodal,
  }) = _UserConfig;
  factory UserConfig.fromJson(Map<String, Object> json) =>
      _$UserConfigFromJson(json);
  factory UserConfig.fromStr(String jsonStr) =>
      _$UserConfigFromJson(json.decode(jsonStr));
}

extension UserConfigDbPath on UserConfig {
  /// user.db 实际所在目录：未配置 `dbDir` 时回落到 `output`。
  String get effectiveDbDir => dbDir.isEmpty ? output : dbDir;
}
