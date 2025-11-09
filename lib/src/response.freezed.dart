// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DataResponse<T> {
  T get data;
  int get totalCount;

  /// Create a copy of DataResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DataResponseCopyWith<T, DataResponse<T>> get copyWith =>
      _$DataResponseCopyWithImpl<T, DataResponse<T>>(
          this as DataResponse<T>, _$identity);

  /// Serializes this DataResponse to a JSON map.
  Map<String, dynamic> toJson(Object? Function(T) toJsonT);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DataResponse<T> &&
            const DeepCollectionEquality().equals(other.data, data) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(data), totalCount);

  @override
  String toString() {
    return 'DataResponse<$T>(data: $data, totalCount: $totalCount)';
  }
}

/// @nodoc
abstract mixin class $DataResponseCopyWith<T, $Res> {
  factory $DataResponseCopyWith(
          DataResponse<T> value, $Res Function(DataResponse<T>) _then) =
      _$DataResponseCopyWithImpl;
  @useResult
  $Res call({T data, int totalCount});
}

/// @nodoc
class _$DataResponseCopyWithImpl<T, $Res>
    implements $DataResponseCopyWith<T, $Res> {
  _$DataResponseCopyWithImpl(this._self, this._then);

  final DataResponse<T> _self;
  final $Res Function(DataResponse<T>) _then;

  /// Create a copy of DataResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = freezed,
    Object? totalCount = null,
  }) {
    return _then(_self.copyWith(
      data: freezed == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as T,
      totalCount: null == totalCount
          ? _self.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [DataResponse].
extension DataResponsePatterns<T> on DataResponse<T> {
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
    TResult Function(_DataResponse<T> value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DataResponse() when $default != null:
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
    TResult Function(_DataResponse<T> value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DataResponse():
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
    TResult? Function(_DataResponse<T> value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DataResponse() when $default != null:
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
    TResult Function(T data, int totalCount)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DataResponse() when $default != null:
        return $default(_that.data, _that.totalCount);
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
    TResult Function(T data, int totalCount) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DataResponse():
        return $default(_that.data, _that.totalCount);
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
    TResult? Function(T data, int totalCount)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DataResponse() when $default != null:
        return $default(_that.data, _that.totalCount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)
class _DataResponse<T> implements DataResponse<T> {
  _DataResponse(this.data, {this.totalCount = 0});
  factory _DataResponse.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$DataResponseFromJson(json, fromJsonT);

  @override
  final T data;
  @override
  @JsonKey()
  final int totalCount;

  /// Create a copy of DataResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DataResponseCopyWith<T, _DataResponse<T>> get copyWith =>
      __$DataResponseCopyWithImpl<T, _DataResponse<T>>(this, _$identity);

  @override
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
    return _$DataResponseToJson<T>(this, toJsonT);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DataResponse<T> &&
            const DeepCollectionEquality().equals(other.data, data) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(data), totalCount);

  @override
  String toString() {
    return 'DataResponse<$T>(data: $data, totalCount: $totalCount)';
  }
}

/// @nodoc
abstract mixin class _$DataResponseCopyWith<T, $Res>
    implements $DataResponseCopyWith<T, $Res> {
  factory _$DataResponseCopyWith(
          _DataResponse<T> value, $Res Function(_DataResponse<T>) _then) =
      __$DataResponseCopyWithImpl;
  @override
  @useResult
  $Res call({T data, int totalCount});
}

/// @nodoc
class __$DataResponseCopyWithImpl<T, $Res>
    implements _$DataResponseCopyWith<T, $Res> {
  __$DataResponseCopyWithImpl(this._self, this._then);

  final _DataResponse<T> _self;
  final $Res Function(_DataResponse<T>) _then;

  /// Create a copy of DataResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? data = freezed,
    Object? totalCount = null,
  }) {
    return _then(_DataResponse<T>(
      freezed == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as T,
      totalCount: null == totalCount
          ? _self.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
