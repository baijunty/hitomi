// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_UserConfig _$$_UserConfigFromJson(Map<String, dynamic> json) =>
    _$_UserConfig(
      json['output'] as String,
      maxTasks: json['maxTasks'] as int? ?? 5,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ["japanese", "chinese"],
      proxy: json['proxy'] as String? ?? "",
      excludes: (json['excludes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      dateLimit: json['dateLimit'] as String? ?? "1970-01-01",
      auth: json['auth'] as String? ?? "12345678",
      logLevel: json['logLevel'] as String? ?? "debug",
      logOutput: json['logOutput'] as String? ?? "",
    );

Map<String, dynamic> _$$_UserConfigToJson(_$_UserConfig instance) =>
    <String, dynamic>{
      'output': instance.output,
      'maxTasks': instance.maxTasks,
      'languages': instance.languages,
      'proxy': instance.proxy,
      'excludes': instance.excludes,
      'dateLimit': instance.dateLimit,
      'auth': instance.auth,
      'logLevel': instance.logLevel,
      'logOutput': instance.logOutput,
    };
