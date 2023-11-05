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
      exinclude: (json['exinclude'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      dateLimit: json['dateLimit'] as String? ?? "1970-01-01",
    );

Map<String, dynamic> _$$_UserConfigToJson(_$_UserConfig instance) =>
    <String, dynamic>{
      'output': instance.output,
      'maxTasks': instance.maxTasks,
      'languages': instance.languages,
      'proxy': instance.proxy,
      'exinclude': instance.exinclude,
      'dateLimit': instance.dateLimit,
    };
