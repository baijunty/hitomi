import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

@immutable
class Character with Lable {
  final String character;
  final String? url;

  const Character({required this.character, this.url});

  @override
  String toString() => 'Character(character: $character, url: $url)';

  factory Character.fromMap(Map<String, dynamic> data) => Character(
        character: data['character'] as String,
        url: data['url'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'character': character,
        'url': url,
      };

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
    String? url,
  }) {
    return Character(
      character: character ?? this.character,
      url: url ?? this.url,
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
  int get hashCode => character.hashCode ^ url.hashCode;

  @override
  String get name => character;

  @override
  String get type => 'character';
}
