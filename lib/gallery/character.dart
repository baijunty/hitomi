import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

class Character with Label {
  final String character;

  Character({required this.character});

  factory Character.fromMap(Map<String, dynamic> data) => Character(
        character: data['character'] as String,
      );

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Character].
  factory Character.fromJson(String data) {
    return Character.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Character] to a JSON string.
  String toJson() => json.encode(toMap());

  Character copyWith({
    String? character,
  }) {
    return Character(
      character: character ?? this.character,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Character) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode => character.hashCode;

  @override
  String get name => character;

  @override
  String get type => 'character';
}
