import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

class Tag with Lable {
  final dynamic male;
  final String tag;
  final dynamic female;

  Tag({this.male, required this.tag, this.female});

  factory Tag.fromMap(Map<String, dynamic> data) => Tag(
        male: data['male'],
        tag: data['tag'] as String,
        female: data['female'],
      );

  Map<String, dynamic> toMap() => {
        'male': male,
        'tag': tag,
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
    String? female,
  }) {
    return Tag(
      male: male ?? this.male,
      tag: tag ?? this.tag,
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
  int get hashCode => male.hashCode ^ tag.hashCode ^ female.hashCode;

  @override
  String get type {
    String? sexTag = (male ?? female)?.toString();
    return sexTag == null
        ? 'tag'
        : '1' == (male?.toString())
            ? 'male'
            : 'female';
  }

  @override
  String get name => tag;

  @override
  String urlEncode() {
    String? sexTag = (male ?? female)?.toString();
    return 'tag/${sexTag == null ? '' : '${'1' == (male?.toString()) ? 'male' : 'female'}:'}${Uri.encodeComponent(name.toLowerCase())}';
  }
}
