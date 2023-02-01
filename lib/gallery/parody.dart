import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

@immutable
class Parody with Lable {
  final String? url;
  final String parody;

  const Parody({this.url, required this.parody});

  @override
  String toString() => 'Parody(url: $url, parody: $parody)';

  factory Parody.fromMap(Map<String, dynamic> data) => Parody(
        url: data['url'] as String?,
        parody: data['parody'] as String,
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'parody': parody,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Parody].
  factory Parody.fromJson(String data) {
    return Parody.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Parody] to a JSON string.
  String toJson() => json.encode(toMap());

  Parody copyWith({
    String? url,
    String? parody,
  }) {
    return Parody(
      url: url ?? this.url,
      parody: parody ?? this.parody,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Parody) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode => url.hashCode ^ parody.hashCode;

  @override
  String get type => 'series';

  @override
  String get name => parody;
}
