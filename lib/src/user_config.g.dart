// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_UserConfig _$$_UserConfigFromJson(Map<String, dynamic> json) =>
    _$_UserConfig(
      json['output'] as String,
      proxy: json['proxy'] as String,
      languages:
          (json['languages'] as List<dynamic>).map((e) => e as String).toList(),
      maxTasks: json['maxTasks'] as int,
      exinclude: (json['exinclude'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      dateLimit: json['dateLimit'] as String?,
    );

Map<String, dynamic> _$$_UserConfigToJson(_$_UserConfig instance) =>
    <String, dynamic>{
      'output': instance.output,
      'proxy': instance.proxy,
      'languages': instance.languages,
      'maxTasks': instance.maxTasks,
      'exinclude': instance.exinclude,
      'dateLimit': instance.dateLimit,
    };
