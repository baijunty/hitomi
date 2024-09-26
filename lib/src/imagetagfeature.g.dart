// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imagetagfeature.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ImageTagFeatureImpl _$$ImageTagFeatureImplFromJson(
        Map<String, dynamic> json) =>
    _$ImageTagFeatureImpl(
      json['fileName'] as String,
      (json['data'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      (json['tags'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$$ImageTagFeatureImplToJson(
        _$ImageTagFeatureImpl instance) =>
    <String, dynamic>{
      'fileName': instance.fileName,
      'data': instance.data,
      'tags': instance.tags,
    };
