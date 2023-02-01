import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

@immutable
class Tag with Lable {
  final dynamic male;
  final String tag;
  final String? url;
  final dynamic female;

  const Tag({this.male, required this.tag, this.url, this.female});

  @override
  String toString() {
    return 'Tag(male: $male, tag: $tag, url: $url, female: $female)';
  }

  factory Tag.fromMap(Map<String, dynamic> data) => Tag(
        male: data['male'],
        tag: data['tag'] as String,
        url: data['url'] as String?,
        female: data['female'],
      );

  Map<String, dynamic> toMap() => {
        'male': male,
        'tag': tag,
        'url': url,
        'female': female,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Tag].
  factory Tag.fromJson(String data) {
    return Tag.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Tag] to a JSON string.
  String toJson() => json.encode(toMap());

  Tag copyWith({
    String? male,
    String? tag,
    String? url,
    String? female,
  }) {
    return Tag(
      male: male ?? this.male,
      tag: tag ?? this.tag,
      url: url ?? this.url,
      female: female ?? this.female,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Tag) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode =>
      male.hashCode ^ tag.hashCode ^ url.hashCode ^ female.hashCode;

  @override
  String get type {
    String? sexTag = male ?? female;
    return sexTag == null
        ? 'tag'
        : male != null
            ? 'male'
            : 'female';
  }

  @override
  String get name => tag;

  @override
  String urlEncode() {
    String? sexTag = male ?? female;
    return 'tag/${sexTag == null ? '' : '$sexTag:'}${Uri.encodeComponent(name.toLowerCase())}';
  }
}
