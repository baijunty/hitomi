import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

@immutable
class Image {
  final String hash;
  final int hasavif;
  final int width;
  final int haswebp;
  final String name;
  final int height;

  const Image({
    required this.hash,
    required this.hasavif,
    required this.width,
    required this.haswebp,
    required this.name,
    required this.height,
  });

  @override
  String toString() {
    return 'File(hash: $hash, hasavif: $hasavif, width: $width, haswebp: $haswebp, name: $name, height: $height)';
  }

  factory Image.fromMap(Map<String, dynamic> data) => Image(
        hash: data['hash'] as String,
        hasavif: data['hasavif'] as int,
        width: data['width'] as int,
        haswebp: data['haswebp'] as int,
        name: data['name'] as String,
        height: data['height'] as int,
      );

  Map<String, dynamic> toMap() => {
        'hash': hash,
        'hasavif': hasavif,
        'width': width,
        'haswebp': haswebp,
        'name': name,
        'height': height,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Image].
  factory Image.fromJson(String data) {
    return Image.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Image] to a JSON string.
  String toJson() => json.encode(toMap());

  Image copyWith({
    String? hash,
    int? hasavif,
    int? width,
    int? haswebp,
    String? name,
    int? height,
  }) {
    return Image(
      hash: hash ?? this.hash,
      hasavif: hasavif ?? this.hasavif,
      width: width ?? this.width,
      haswebp: haswebp ?? this.haswebp,
      name: name ?? this.name,
      height: height ?? this.height,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Image) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode =>
      hash.hashCode ^
      hasavif.hashCode ^
      width.hashCode ^
      haswebp.hashCode ^
      name.hashCode ^
      height.hashCode;
}
