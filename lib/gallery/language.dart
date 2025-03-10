import 'dart:convert';

import 'package:hitomi/gallery/label.dart';

import '../lib.dart';

class Language with Label {
  static final chinese = Language(name: 'chinese');
  static final japanese = Language(name: 'japanese');
  static final english = Language(name: 'english');
  final String? galleryid;
  final String? languageLocalname;
  final String name;

  Language({
    this.galleryid,
    this.languageLocalname,
    required this.name,
  });

  factory Language.fromMap(Map<String, dynamic> data) => Language(
        galleryid: data['galleryid']?.toString(),
        languageLocalname: data['language_localname'] as String?,
        name: data['name'] as String,
      );

  Map<String, dynamic> toMap() => {
        'galleryid': galleryid,
        'language_localname': languageLocalname,
        'name': name,
        'type': type
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
    String? name,
  }) {
    return Language(
      galleryid: galleryid ?? this.galleryid,
      languageLocalname: languageLocalname ?? this.languageLocalname,
      name: name ?? this.name,
    );
  }

  @override
  String get type => 'language';

  @override
  String urlEncode({SortEnum? sort}) {
    return '${sort == null || sort == SortEnum.Default ? 'index' : 'popular/${sort.name}'}-$name';
  }
}
