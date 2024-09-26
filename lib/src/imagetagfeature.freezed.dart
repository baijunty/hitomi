// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'imagetagfeature.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ImageTagFeature _$ImageTagFeatureFromJson(Map<String, dynamic> json) {
  return _ImageTagFeature.fromJson(json);
}

/// @nodoc
mixin _$ImageTagFeature {
  String get fileName => throw _privateConstructorUsedError;
  List<double>? get data => throw _privateConstructorUsedError;
  Map<String, double>? get tags => throw _privateConstructorUsedError;

  /// Serializes this ImageTagFeature to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ImageTagFeatureCopyWith<ImageTagFeature> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImageTagFeatureCopyWith<$Res> {
  factory $ImageTagFeatureCopyWith(
          ImageTagFeature value, $Res Function(ImageTagFeature) then) =
      _$ImageTagFeatureCopyWithImpl<$Res, ImageTagFeature>;
  @useResult
  $Res call({String fileName, List<double>? data, Map<String, double>? tags});
}

/// @nodoc
class _$ImageTagFeatureCopyWithImpl<$Res, $Val extends ImageTagFeature>
    implements $ImageTagFeatureCopyWith<$Res> {
  _$ImageTagFeatureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fileName = null,
    Object? data = freezed,
    Object? tags = freezed,
  }) {
    return _then(_value.copyWith(
      fileName: null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      data: freezed == data
          ? _value.data
          : data // ignore: cast_nullable_to_non_nullable
              as List<double>?,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as Map<String, double>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ImageTagFeatureImplCopyWith<$Res>
    implements $ImageTagFeatureCopyWith<$Res> {
  factory _$$ImageTagFeatureImplCopyWith(_$ImageTagFeatureImpl value,
          $Res Function(_$ImageTagFeatureImpl) then) =
      __$$ImageTagFeatureImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String fileName, List<double>? data, Map<String, double>? tags});
}

/// @nodoc
class __$$ImageTagFeatureImplCopyWithImpl<$Res>
    extends _$ImageTagFeatureCopyWithImpl<$Res, _$ImageTagFeatureImpl>
    implements _$$ImageTagFeatureImplCopyWith<$Res> {
  __$$ImageTagFeatureImplCopyWithImpl(
      _$ImageTagFeatureImpl _value, $Res Function(_$ImageTagFeatureImpl) _then)
      : super(_value, _then);

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fileName = null,
    Object? data = freezed,
    Object? tags = freezed,
  }) {
    return _then(_$ImageTagFeatureImpl(
      null == fileName
          ? _value.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      freezed == data
          ? _value._data
          : data // ignore: cast_nullable_to_non_nullable
              as List<double>?,
      freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as Map<String, double>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ImageTagFeatureImpl implements _ImageTagFeature {
  _$ImageTagFeatureImpl(
      this.fileName, final List<double>? data, final Map<String, double>? tags)
      : _data = data,
        _tags = tags;

  factory _$ImageTagFeatureImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImageTagFeatureImplFromJson(json);

  @override
  final String fileName;
  final List<double>? _data;
  @override
  List<double>? get data {
    final value = _data;
    if (value == null) return null;
    if (_data is EqualUnmodifiableListView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, double>? _tags;
  @override
  Map<String, double>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableMapView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'ImageTagFeature(fileName: $fileName, data: $data, tags: $tags)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImageTagFeatureImpl &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            const DeepCollectionEquality().equals(other._data, _data) &&
            const DeepCollectionEquality().equals(other._tags, _tags));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      fileName,
      const DeepCollectionEquality().hash(_data),
      const DeepCollectionEquality().hash(_tags));

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ImageTagFeatureImplCopyWith<_$ImageTagFeatureImpl> get copyWith =>
      __$$ImageTagFeatureImplCopyWithImpl<_$ImageTagFeatureImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ImageTagFeatureImplToJson(
      this,
    );
  }
}

abstract class _ImageTagFeature implements ImageTagFeature {
  factory _ImageTagFeature(final String fileName, final List<double>? data,
      final Map<String, double>? tags) = _$ImageTagFeatureImpl;

  factory _ImageTagFeature.fromJson(Map<String, dynamic> json) =
      _$ImageTagFeatureImpl.fromJson;

  @override
  String get fileName;
  @override
  List<double>? get data;
  @override
  Map<String, double>? get tags;

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImageTagFeatureImplCopyWith<_$ImageTagFeatureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
