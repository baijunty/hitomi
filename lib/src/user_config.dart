import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
part 'user_config.freezed.dart';
part 'user_config.g.dart';

@immutable
@freezed
class UserConfig with _$UserConfig {
  factory UserConfig(
    String output, {
    @Default(5) int maxTasks,
    @Default(["japanese", "chinese"]) List<String> languages,
    @Default("") String proxy,
    @Default([]) List<String> excludes,
    @Default("1970-01-01") String dateLimit,
    @Default("12345678") String auth,
    @Default("debug") String logLevel,
    @Default("") String logOutput,
  }) = _UserConfig;
  factory UserConfig.fromJson(Map<String, Object> json) =>
      _$UserConfigFromJson(json);
  factory UserConfig.fromStr(String jsonStr) =>
      _$UserConfigFromJson(json.decode(jsonStr));
}
