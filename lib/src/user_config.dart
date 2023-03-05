import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
part 'user_config.freezed.dart';
part 'user_config.g.dart';

@immutable
@freezed
class UserConfig with _$UserConfig {
  factory UserConfig(String output,
      {required String proxy,
      required List<String> languages,
      required int maxTasks,
      List<String>? exinclude,
      String? dateLimit}) = _UserConfig;
  factory UserConfig.fromJson(Map<String, Object> json) =>
      _$UserConfigFromJson(json);
  factory UserConfig.fromStr(String jsonStr) =>
      _$UserConfigFromJson(json.decode(jsonStr));
}
