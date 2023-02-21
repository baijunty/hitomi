import 'package:freezed_annotation/freezed_annotation.dart';
part 'user_config.freezed.dart';
part 'user_config.g.dart';

@immutable
@freezed
class UserConfig with _$UserConfig {
  const factory UserConfig(String output,
      {required String proxy,
      required List<String> languages,
      required int maxTasks}) = _UserConfig;
  factory UserConfig.fromJson(Map<String, Object> json) =>
      _$UserConfigFromJson(json);
}
