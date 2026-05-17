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
