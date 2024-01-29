import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

class Artist with Lable {
  final String artist;

  Artist({required this.artist});

  factory Artist.fromMap(Map<String, dynamic> data) => Artist(
        artist: data['artist'] as String,
      );

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Artist].
  factory Artist.fromJson(String data) {
    return Artist.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Artist] to a JSON string.
  String toJson() => json.encode(toMap());

  Artist copyWith({
    String? artist,
  }) {
    return Artist(
      artist: artist ?? this.artist,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Artist) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode => artist.hashCode;

  @override
  String get name => artist;

  @override
  String get type => 'artist';
}
