// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'imagetagfeature.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ImageTagFeature {
  String get fileName;
  List<double>? get data;
  Map<String, double>? get tags;

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImageTagFeatureCopyWith<ImageTagFeature> get copyWith =>
      _$ImageTagFeatureCopyWithImpl<ImageTagFeature>(
          this as ImageTagFeature, _$identity);

  /// Serializes this ImageTagFeature to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImageTagFeature &&
            (identical(other.fileName, fileName) ||
                other.fileName == fileName) &&
            const DeepCollectionEquality().equals(other.data, data) &&
            const DeepCollectionEquality().equals(other.tags, tags));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      fileName,
      const DeepCollectionEquality().hash(data),
      const DeepCollectionEquality().hash(tags));

  @override
  String toString() {
    return 'ImageTagFeature(fileName: $fileName, data: $data, tags: $tags)';
  }
}

/// @nodoc
abstract mixin class $ImageTagFeatureCopyWith<$Res> {
  factory $ImageTagFeatureCopyWith(
          ImageTagFeature value, $Res Function(ImageTagFeature) _then) =
      _$ImageTagFeatureCopyWithImpl;
  @useResult
  $Res call({String fileName, List<double>? data, Map<String, double>? tags});
}

/// @nodoc
class _$ImageTagFeatureCopyWithImpl<$Res>
    implements $ImageTagFeatureCopyWith<$Res> {
  _$ImageTagFeatureCopyWithImpl(this._self, this._then);

  final ImageTagFeature _self;
  final $Res Function(ImageTagFeature) _then;

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fileName = null,
    Object? data = freezed,
    Object? tags = freezed,
  }) {
    return _then(_self.copyWith(
      fileName: null == fileName
          ? _self.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      data: freezed == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as List<double>?,
      tags: freezed == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as Map<String, double>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ImageTagFeature].
extension ImageTagFeaturePatterns on ImageTagFeature {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ImageTagFeature value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImageTagFeature() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ImageTagFeature value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageTagFeature():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ImageTagFeature value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageTagFeature() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String fileName, List<double>? data, Map<String, double>? tags)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImageTagFeature() when $default != null:
        return $default(_that.fileName, _that.data, _that.tags);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String fileName, List<double>? data, Map<String, double>? tags)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageTagFeature():
        return $default(_that.fileName, _that.data, _that.tags);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String fileName, List<double>? data, Map<String, double>? tags)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImageTagFeature() when $default != null:
        return $default(_that.fileName, _that.data, _that.tags);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ImageTagFeature implements ImageTagFeature {
  _ImageTagFeature(
      this.fileName, final List<double>? data, final Map<String, double>? tags)
      : _data = data,
        _tags = tags;
  factory _ImageTagFeature.fromJson(Map<String, dynamic> json) =>
      _$ImageTagFeatureFromJson(json);

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

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ImageTagFeatureCopyWith<_ImageTagFeature> get copyWith =>
      __$ImageTagFeatureCopyWithImpl<_ImageTagFeature>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ImageTagFeatureToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ImageTagFeature &&
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

  @override
  String toString() {
    return 'ImageTagFeature(fileName: $fileName, data: $data, tags: $tags)';
  }
}

/// @nodoc
abstract mixin class _$ImageTagFeatureCopyWith<$Res>
    implements $ImageTagFeatureCopyWith<$Res> {
  factory _$ImageTagFeatureCopyWith(
          _ImageTagFeature value, $Res Function(_ImageTagFeature) _then) =
      __$ImageTagFeatureCopyWithImpl;
  @override
  @useResult
  $Res call({String fileName, List<double>? data, Map<String, double>? tags});
}

/// @nodoc
class __$ImageTagFeatureCopyWithImpl<$Res>
    implements _$ImageTagFeatureCopyWith<$Res> {
  __$ImageTagFeatureCopyWithImpl(this._self, this._then);

  final _ImageTagFeature _self;
  final $Res Function(_ImageTagFeature) _then;

  /// Create a copy of ImageTagFeature
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? fileName = null,
    Object? data = freezed,
    Object? tags = freezed,
  }) {
    return _then(_ImageTagFeature(
      null == fileName
          ? _self.fileName
          : fileName // ignore: cast_nullable_to_non_nullable
              as String,
      freezed == data
          ? _self._data
          : data // ignore: cast_nullable_to_non_nullable
              as List<double>?,
      freezed == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as Map<String, double>?,
    ));
  }
}

// dart format on
