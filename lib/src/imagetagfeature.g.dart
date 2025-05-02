// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imagetagfeature.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ImageTagFeature _$ImageTagFeatureFromJson(Map<String, dynamic> json) =>
    _ImageTagFeature(
      json['fileName'] as String,
      (json['data'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      (json['tags'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$ImageTagFeatureToJson(_ImageTagFeature instance) =>
    <String, dynamic>{
      'fileName': instance.fileName,
      'data': instance.data,
      'tags': instance.tags,
    };
