// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserConfig {
  String get output;
  int get maxTasks;
  List<String> get languages;
  String get proxy;
  List<FilterLabel> get excludes;
  String get dateLimit;
  String get auth;
  String get logLevel;
  String get logOutput;
  String get aiTagPath;
  String get remoteHttp;
  double get threshold;

  /// Create a copy of UserConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserConfigCopyWith<UserConfig> get copyWith =>
      _$UserConfigCopyWithImpl<UserConfig>(this as UserConfig, _$identity);

  /// Serializes this UserConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserConfig &&
            (identical(other.output, output) || other.output == output) &&
            (identical(other.maxTasks, maxTasks) ||
                other.maxTasks == maxTasks) &&
            const DeepCollectionEquality().equals(other.languages, languages) &&
            (identical(other.proxy, proxy) || other.proxy == proxy) &&
            const DeepCollectionEquality().equals(other.excludes, excludes) &&
            (identical(other.dateLimit, dateLimit) ||
                other.dateLimit == dateLimit) &&
            (identical(other.auth, auth) || other.auth == auth) &&
            (identical(other.logLevel, logLevel) ||
                other.logLevel == logLevel) &&
            (identical(other.logOutput, logOutput) ||
                other.logOutput == logOutput) &&
            (identical(other.aiTagPath, aiTagPath) ||
                other.aiTagPath == aiTagPath) &&
            (identical(other.remoteHttp, remoteHttp) ||
                other.remoteHttp == remoteHttp) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      output,
      maxTasks,
      const DeepCollectionEquality().hash(languages),
      proxy,
      const DeepCollectionEquality().hash(excludes),
      dateLimit,
      auth,
      logLevel,
      logOutput,
      aiTagPath,
      remoteHttp,
      threshold);

  @override
  String toString() {
    return 'UserConfig(output: $output, maxTasks: $maxTasks, languages: $languages, proxy: $proxy, excludes: $excludes, dateLimit: $dateLimit, auth: $auth, logLevel: $logLevel, logOutput: $logOutput, aiTagPath: $aiTagPath, remoteHttp: $remoteHttp, threshold: $threshold)';
  }
}

/// @nodoc
abstract mixin class $UserConfigCopyWith<$Res> {
  factory $UserConfigCopyWith(
          UserConfig value, $Res Function(UserConfig) _then) =
      _$UserConfigCopyWithImpl;
  @useResult
  $Res call(
      {String output,
      int maxTasks,
      List<String> languages,
      String proxy,
      List<FilterLabel> excludes,
      String dateLimit,
      String auth,
      String logLevel,
      String logOutput,
      String aiTagPath,
      String remoteHttp,
      double threshold});
}

/// @nodoc
class _$UserConfigCopyWithImpl<$Res> implements $UserConfigCopyWith<$Res> {
  _$UserConfigCopyWithImpl(this._self, this._then);

  final UserConfig _self;
  final $Res Function(UserConfig) _then;

  /// Create a copy of UserConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? output = null,
    Object? maxTasks = null,
    Object? languages = null,
    Object? proxy = null,
    Object? excludes = null,
    Object? dateLimit = null,
    Object? auth = null,
    Object? logLevel = null,
    Object? logOutput = null,
    Object? aiTagPath = null,
    Object? remoteHttp = null,
    Object? threshold = null,
  }) {
    return _then(_self.copyWith(
      output: null == output
          ? _self.output
          : output // ignore: cast_nullable_to_non_nullable
              as String,
      maxTasks: null == maxTasks
          ? _self.maxTasks
          : maxTasks // ignore: cast_nullable_to_non_nullable
              as int,
      languages: null == languages
          ? _self.languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      proxy: null == proxy
          ? _self.proxy
          : proxy // ignore: cast_nullable_to_non_nullable
              as String,
      excludes: null == excludes
          ? _self.excludes
          : excludes // ignore: cast_nullable_to_non_nullable
              as List<FilterLabel>,
      dateLimit: null == dateLimit
          ? _self.dateLimit
          : dateLimit // ignore: cast_nullable_to_non_nullable
              as String,
      auth: null == auth
          ? _self.auth
          : auth // ignore: cast_nullable_to_non_nullable
              as String,
      logLevel: null == logLevel
          ? _self.logLevel
          : logLevel // ignore: cast_nullable_to_non_nullable
              as String,
      logOutput: null == logOutput
          ? _self.logOutput
          : logOutput // ignore: cast_nullable_to_non_nullable
              as String,
      aiTagPath: null == aiTagPath
          ? _self.aiTagPath
          : aiTagPath // ignore: cast_nullable_to_non_nullable
              as String,
      remoteHttp: null == remoteHttp
          ? _self.remoteHttp
          : remoteHttp // ignore: cast_nullable_to_non_nullable
              as String,
      threshold: null == threshold
          ? _self.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _UserConfig implements UserConfig {
  _UserConfig(this.output,
      {this.maxTasks = 5,
      final List<String> languages = const ["japanese", "chinese"],
      this.proxy = "",
      final List<FilterLabel> excludes = const [],
      this.dateLimit = "2013-01-01",
      this.auth = "12345678",
      this.logLevel = "debug",
      this.logOutput = "",
      this.aiTagPath = "",
      this.remoteHttp = "127.0.0.1:7890",
      this.threshold = 0.72})
      : _languages = languages,
        _excludes = excludes;
  factory _UserConfig.fromJson(Map<String, dynamic> json) =>
      _$UserConfigFromJson(json);

  @override
  final String output;
  @override
  @JsonKey()
  final int maxTasks;
  final List<String> _languages;
  @override
  @JsonKey()
  List<String> get languages {
    if (_languages is EqualUnmodifiableListView) return _languages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_languages);
  }

  @override
  @JsonKey()
  final String proxy;
  final List<FilterLabel> _excludes;
  @override
  @JsonKey()
  List<FilterLabel> get excludes {
    if (_excludes is EqualUnmodifiableListView) return _excludes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_excludes);
  }

  @override
  @JsonKey()
  final String dateLimit;
  @override
  @JsonKey()
  final String auth;
  @override
  @JsonKey()
  final String logLevel;
  @override
  @JsonKey()
  final String logOutput;
  @override
  @JsonKey()
  final String aiTagPath;
  @override
  @JsonKey()
  final String remoteHttp;
  @override
  @JsonKey()
  final double threshold;

  /// Create a copy of UserConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserConfigCopyWith<_UserConfig> get copyWith =>
      __$UserConfigCopyWithImpl<_UserConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$UserConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserConfig &&
            (identical(other.output, output) || other.output == output) &&
            (identical(other.maxTasks, maxTasks) ||
                other.maxTasks == maxTasks) &&
            const DeepCollectionEquality()
                .equals(other._languages, _languages) &&
            (identical(other.proxy, proxy) || other.proxy == proxy) &&
            const DeepCollectionEquality().equals(other._excludes, _excludes) &&
            (identical(other.dateLimit, dateLimit) ||
                other.dateLimit == dateLimit) &&
            (identical(other.auth, auth) || other.auth == auth) &&
            (identical(other.logLevel, logLevel) ||
                other.logLevel == logLevel) &&
            (identical(other.logOutput, logOutput) ||
                other.logOutput == logOutput) &&
            (identical(other.aiTagPath, aiTagPath) ||
                other.aiTagPath == aiTagPath) &&
            (identical(other.remoteHttp, remoteHttp) ||
                other.remoteHttp == remoteHttp) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      output,
      maxTasks,
      const DeepCollectionEquality().hash(_languages),
      proxy,
      const DeepCollectionEquality().hash(_excludes),
      dateLimit,
      auth,
      logLevel,
      logOutput,
      aiTagPath,
      remoteHttp,
      threshold);

  @override
  String toString() {
    return 'UserConfig(output: $output, maxTasks: $maxTasks, languages: $languages, proxy: $proxy, excludes: $excludes, dateLimit: $dateLimit, auth: $auth, logLevel: $logLevel, logOutput: $logOutput, aiTagPath: $aiTagPath, remoteHttp: $remoteHttp, threshold: $threshold)';
  }
}

/// @nodoc
abstract mixin class _$UserConfigCopyWith<$Res>
    implements $UserConfigCopyWith<$Res> {
  factory _$UserConfigCopyWith(
          _UserConfig value, $Res Function(_UserConfig) _then) =
      __$UserConfigCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String output,
      int maxTasks,
      List<String> languages,
      String proxy,
      List<FilterLabel> excludes,
      String dateLimit,
      String auth,
      String logLevel,
      String logOutput,
      String aiTagPath,
      String remoteHttp,
      double threshold});
}

/// @nodoc
class __$UserConfigCopyWithImpl<$Res> implements _$UserConfigCopyWith<$Res> {
  __$UserConfigCopyWithImpl(this._self, this._then);

  final _UserConfig _self;
  final $Res Function(_UserConfig) _then;

  /// Create a copy of UserConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? output = null,
    Object? maxTasks = null,
    Object? languages = null,
    Object? proxy = null,
    Object? excludes = null,
    Object? dateLimit = null,
    Object? auth = null,
    Object? logLevel = null,
    Object? logOutput = null,
    Object? aiTagPath = null,
    Object? remoteHttp = null,
    Object? threshold = null,
  }) {
    return _then(_UserConfig(
      null == output
          ? _self.output
          : output // ignore: cast_nullable_to_non_nullable
              as String,
      maxTasks: null == maxTasks
          ? _self.maxTasks
          : maxTasks // ignore: cast_nullable_to_non_nullable
              as int,
      languages: null == languages
          ? _self._languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>,
      proxy: null == proxy
          ? _self.proxy
          : proxy // ignore: cast_nullable_to_non_nullable
              as String,
      excludes: null == excludes
          ? _self._excludes
          : excludes // ignore: cast_nullable_to_non_nullable
              as List<FilterLabel>,
      dateLimit: null == dateLimit
          ? _self.dateLimit
          : dateLimit // ignore: cast_nullable_to_non_nullable
              as String,
      auth: null == auth
          ? _self.auth
          : auth // ignore: cast_nullable_to_non_nullable
              as String,
      logLevel: null == logLevel
          ? _self.logLevel
          : logLevel // ignore: cast_nullable_to_non_nullable
              as String,
      logOutput: null == logOutput
          ? _self.logOutput
          : logOutput // ignore: cast_nullable_to_non_nullable
              as String,
      aiTagPath: null == aiTagPath
          ? _self.aiTagPath
          : aiTagPath // ignore: cast_nullable_to_non_nullable
              as String,
      remoteHttp: null == remoteHttp
          ? _self.remoteHttp
          : remoteHttp // ignore: cast_nullable_to_non_nullable
              as String,
      threshold: null == threshold
          ? _self.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
