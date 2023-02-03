import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/lib.dart';

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

  String getDownLoadUrl(UserContext context) {
    return "https://${_getUserInfo(context, hash, 'a')}.hitomi.la/webp/${context.code}/${_parseLast3HashCode(hash)}/${hash}.webp";
  }

  String getThumbnailUrl(UserContext context,
      {ThumbnaiSize size = ThumbnaiSize.smaill}) {
    final lastThreeCode = hash.substring(hash.length - 3);
    var sizeStr;
    switch (size) {
      case ThumbnaiSize.smaill:
        sizeStr = 'webpsmallsmalltn';
        break;
      case ThumbnaiSize.medium:
        sizeStr = 'webpsmalltn';
        break;
      case ThumbnaiSize.big:
        sizeStr = 'webpbigtn';
        break;
    }
    return "https://${_getUserInfo(context, hash, 'tn')}.hitomi.la/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${hash}.webp";
  }

  String _getUserInfo(UserContext context, String hash, String postFix) {
    final code = _parseLast3HashCode(hash);
    final userInfo = ['a', 'b'];
    var useIndex = context.index -
        (context.codes.any((element) => element == code) ? 1 : 0);
    return userInfo[useIndex.abs()] + postFix;
  }

  int _parseLast3HashCode(String hash) {
    return int.parse(String.fromCharCode(hash.codeUnitAt(hash.length - 1)),
                radix: 16) <<
            8 |
        int.parse(hash.substring(hash.length - 3, hash.length - 1), radix: 16);
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

enum ThumbnaiSize {
  smaill,
  medium,
  big;
}
