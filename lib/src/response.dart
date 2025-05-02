import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'response.freezed.dart';
part 'response.g.dart';

@Freezed(genericArgumentFactories: true)
abstract class DataResponse<T> with _$DataResponse<T> {
  factory DataResponse(
    T data, {
    @Default(0) int totalCount,
  }) = _DataResponse;

  factory DataResponse.fromJson(
          Map<String, Object> json, T Function(Object?) fromJsonT) =>
      _$DataResponseFromJson(json, fromJsonT);
  factory DataResponse.fromStr(String jsonStr, T Function(Object?) fromJsonT) =>
      _$DataResponseFromJson(json.decode(jsonStr), fromJsonT);
}
