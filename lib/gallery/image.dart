import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sqlite3/common.dart';

@immutable
class Image {
  final String hash;
  final int hasavif;
  final int width;
  final String name;
  final int height;
  final int? fileHash;
  const Image({
    required this.hash,
    required this.hasavif,
    required this.width,
    required this.name,
    required this.height,
    this.fileHash,
  });

  factory Image.fromMap(Map<String, dynamic> data) => Image(
    hash: data['hash'] as String,
    hasavif: data['hasavif'] as int,
    width: data['width'] as int,
    name: data['name'] as String,
    height: data['height'] as int,
  );
  factory Image.fromRow(Row row) => Image(
    hash: row['hash'] as String,
    hasavif: 0,
    width: row['width'] as int,
    name: row['name'] as String,
    height: row['height'] as int,
    fileHash: row['fileHash'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'hash': hash,
    'hasavif': hasavif,
    'width': width,
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
      name: name ?? this.name,
      height: height ?? this.height,
    );
  }

  @override
  String toString() {
    return toMap().toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Image) return false;
    return name == other.name && hash == other.hash;
  }

  @override
  int get hashCode =>
      hash.hashCode ^
      hasavif.hashCode ^
      width.hashCode ^
      name.hashCode ^
      height.hashCode;
}

enum ThumbnaiSize {
  smaill,
  medium,
  big,
  origin;

  factory ThumbnaiSize.fromStr(String name) {
    switch (name) {
      case 'smaill':
        {
          return ThumbnaiSize.smaill;
        }
      case 'medium':
        {
          return ThumbnaiSize.medium;
        }
      case 'big':
        {
          return ThumbnaiSize.big;
        }
      default:
        {
          return ThumbnaiSize.origin;
        }
    }
  }
}
