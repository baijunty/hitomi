// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DataResponseImpl<T> _$$DataResponseImplFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    _$DataResponseImpl<T>(
      fromJsonT(json['data']),
      totalCount: json['totalCount'] as int? ?? 0,
    );

Map<String, dynamic> _$$DataResponseImplToJson<T>(
  _$DataResponseImpl<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'data': toJsonT(instance.data),
      'totalCount': instance.totalCount,
    };
