import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

@immutable
class Language with Lable {
  static final chinese = Language(name: 'chinese');
  static final japanese = Language(name: 'japanese');
  static final english = Language(name: 'english');
  final String? galleryid;
  final String? languageLocalname;
  final String? url;
  final String name;

  Language({
    this.galleryid,
    this.languageLocalname,
    this.url,
    required this.name,
  });

  @override
  String toString() {
    return 'Language(galleryid: $galleryid, languageLocalname: $languageLocalname, url: $url, name: $name)';
  }

  factory Language.fromMap(Map<String, dynamic> data) => Language(
        galleryid: data['galleryid'] as String?,
        languageLocalname: data['language_localname'] as String?,
        url: data['url'] as String?,
        name: data['name'] as String,
      );

  Map<String, dynamic> toMap() => {
        'galleryid': galleryid,
        'language_localname': languageLocalname,
        'url': url,
        'name': name,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Language].
  factory Language.fromJson(String data) {
    return Language.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Language] to a JSON string.
  String toJson() => json.encode(toMap());

  Language copyWith({
    String? galleryid,
    String? languageLocalname,
    String? url,
    String? name,
  }) {
    return Language(
      galleryid: galleryid ?? this.galleryid,
      languageLocalname: languageLocalname ?? this.languageLocalname,
      url: url ?? this.url,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Language) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode =>
      galleryid.hashCode ^
      languageLocalname.hashCode ^
      url.hashCode ^
      name.hashCode;

  @override
  String get type => 'language';

  @override
  String urlEncode() {
    return 'index-$name';
  }
}