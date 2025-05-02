// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserConfig _$UserConfigFromJson(Map<String, dynamic> json) => _UserConfig(
      json['output'] as String,
      maxTasks: (json['maxTasks'] as num?)?.toInt() ?? 5,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ["japanese", "chinese"],
      proxy: json['proxy'] as String? ?? "",
      excludes: (json['excludes'] as List<dynamic>?)
              ?.map((e) => FilterLabel.fromJson(e as String))
              .toList() ??
          const [],
      dateLimit: json['dateLimit'] as String? ?? "2013-01-01",
      auth: json['auth'] as String? ?? "12345678",
      logLevel: json['logLevel'] as String? ?? "debug",
      logOutput: json['logOutput'] as String? ?? "",
      aiTagPath: json['aiTagPath'] as String? ?? "",
      remoteHttp: json['remoteHttp'] as String? ?? "127.0.0.1:7890",
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.72,
    );

Map<String, dynamic> _$UserConfigToJson(_UserConfig instance) =>
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
      'aiTagPath': instance.aiTagPath,
      'remoteHttp': instance.remoteHttp,
      'threshold': instance.threshold,
    };
