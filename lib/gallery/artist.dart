import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

@immutable
class Artist with Lable {
  final String? url;
  final String artist;

  Artist({this.url, required this.artist});

  @override
  String toString() => 'Artist(url: $url, artist: $artist)';

  factory Artist.fromMap(Map<String, dynamic> data) => Artist(
        url: data['url'] as String?,
        artist: data['artist'] as String,
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'artist': artist,
      };

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
    String? url,
    String? artist,
  }) {
    return Artist(
      url: url ?? this.url,
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
  int get hashCode => url.hashCode ^ artist.hashCode;

  @override
  String get name => artist;

  @override
  String get type => 'artist';
}
