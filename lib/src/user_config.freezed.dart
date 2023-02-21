// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

UserConfig _$UserConfigFromJson(Map<String, dynamic> json) {
  return _UserConfig.fromJson(json);
}

/// @nodoc
mixin _$UserConfig {
  String get output => throw _privateConstructorUsedError;
  String get proxy => throw _privateConstructorUsedError;
  List<String> get languages => throw _privateConstructorUsedError;
  int get maxTasks => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UserConfigCopyWith<UserConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserConfigCopyWith<$Res> {
  factory $UserConfigCopyWith(
          UserConfig value, $Res Function(UserConfig) then) =
      _$UserConfigCopyWithImpl<$Res, UserConfig>;
  @useResult
  $Res call(
      {String output, String proxy, List<String> languages, int maxTasks});
}

/// @nodoc
class _$UserConfigCopyWithImpl<$Res, $Val extends UserConfig>
    implements $UserConfigCopyWith<$Res> {
  _$UserConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? output = null,
    Object? proxy = null,
    Object? languages = null,
    Object? maxTasks = null,
  }) {
    return _then(_value.copyWith(
      output: null == output
          ? _value.output
          : output // ignore: cast_nullable_to_non_nullable
              as String,
      proxy: null == proxy
          ? _value.proxy
          : proxy // ignore: cast_nullable_to_non_nullable
              as String,
      languages: null == languages
          ? _value.languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      maxTasks: null == maxTasks
          ? _value.maxTasks
          : maxTasks // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_UserConfigCopyWith<$Res>
    implements $UserConfigCopyWith<$Res> {
  factory _$$_UserConfigCopyWith(
          _$_UserConfig value, $Res Function(_$_UserConfig) then) =
      __$$_UserConfigCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String output, String proxy, List<String> languages, int maxTasks});
}

/// @nodoc
class __$$_UserConfigCopyWithImpl<$Res>
    extends _$UserConfigCopyWithImpl<$Res, _$_UserConfig>
    implements _$$_UserConfigCopyWith<$Res> {
  __$$_UserConfigCopyWithImpl(
      _$_UserConfig _value, $Res Function(_$_UserConfig) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? output = null,
    Object? proxy = null,
    Object? languages = null,
    Object? maxTasks = null,
  }) {
    return _then(_$_UserConfig(
      null == output
          ? _value.output
          : output // ignore: cast_nullable_to_non_nullable
              as String,
      proxy: null == proxy
          ? _value.proxy
          : proxy // ignore: cast_nullable_to_non_nullable
              as String,
      languages: null == languages
          ? _value._languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      maxTasks: null == maxTasks
          ? _value.maxTasks
          : maxTasks // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_UserConfig implements _UserConfig {
  const _$_UserConfig(this.output,
      {required this.proxy,
      required final List<String> languages,
      required this.maxTasks})
      : _languages = languages;

  factory _$_UserConfig.fromJson(Map<String, dynamic> json) =>
      _$$_UserConfigFromJson(json);

  @override
  final String output;
  @override
  final String proxy;
  final List<String> _languages;
  @override
  List<String> get languages {
    if (_languages is EqualUnmodifiableListView) return _languages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_languages);
  }

  @override
  final int maxTasks;

  @override
  String toString() {
    return 'UserConfig(output: $output, proxy: $proxy, languages: $languages, maxTasks: $maxTasks)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_UserConfig &&
            (identical(other.output, output) || other.output == output) &&
            (identical(other.proxy, proxy) || other.proxy == proxy) &&
            const DeepCollectionEquality()
                .equals(other._languages, _languages) &&
            (identical(other.maxTasks, maxTasks) ||
                other.maxTasks == maxTasks));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, output, proxy,
      const DeepCollectionEquality().hash(_languages), maxTasks);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_UserConfigCopyWith<_$_UserConfig> get copyWith =>
      __$$_UserConfigCopyWithImpl<_$_UserConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_UserConfigToJson(
      this,
    );
  }
}

abstract class _UserConfig implements UserConfig {
  const factory _UserConfig(final String output,
      {required final String proxy,
      required final List<String> languages,
      required final int maxTasks}) = _$_UserConfig;

  factory _UserConfig.fromJson(Map<String, dynamic> json) =
      _$_UserConfig.fromJson;

  @override
  String get output;
  @override
  String get proxy;
  @override
  List<String> get languages;
  @override
  int get maxTasks;
  @override
  @JsonKey(ignore: true)
  _$$_UserConfigCopyWith<_$_UserConfig> get copyWith =>
      throw _privateConstructorUsedError;
}
