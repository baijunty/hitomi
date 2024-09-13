import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';

import '../lib.dart';
import 'artist.dart';
import 'character.dart';
import 'image.dart';
import 'group.dart';
import 'language.dart';
import 'parody.dart';
import 'tag.dart';

class Gallery with Label {
  static const Map<String, String> illegalCode = {
    r'\': '＼',
    '/': '／',
    '*': '※',
    ':': '∶',
    '?': '？',
    '"': '“',
    '<': '《',
    '>': '》',
    '|': '▎',
    '..': '。。'
  };
  final List<Artist>? artists;
  final List<Tag>? tags;
  final List<dynamic>? sceneIndexes;
  final String? japaneseTitle;
  final List<Language>? languages;
  final String type;
  final String? languageLocalname;
  final String title;
  final String? language;
  final List<Character>? characters;
  final String? galleryurl;
  final String? languageUrl;
  final String date;
  final int? downDate;
  final List<int>? related;
  final String? video;
  final List<Parody>? parodys;
  final String? videofilename;
  final List<Image> files;
  final int id;
  final List<Group>? groups;

  Gallery(
      {this.artists,
      this.tags,
      this.sceneIndexes,
      this.japaneseTitle,
      this.languages,
      required this.type,
      this.languageLocalname,
      required this.title,
      this.language,
      this.characters,
      this.galleryurl,
      this.languageUrl,
      required this.date,
      this.related,
      this.video,
      this.parodys,
      this.videofilename,
      required this.files,
      required this.id,
      this.groups,
      this.downDate});

  List<Label> labels() {
    return <Label>[]
      ..addAll(artists ?? [])
      ..addAll(tags ?? [])
      ..addAll(characters ?? [])
      ..addAll(parodys ?? [])
      ..addAll(groups ?? []);
  }

  @override
  String toString() {
    return 'Gallery(type: $type, title: ${dirName}, language: $language, date: $date, id: $id length:${files.length})';
  }

  factory Gallery.fromRow(Row row) {
    var gallery = Gallery(
        type: row['type'],
        title: row['title'],
        date: row['createDate'],
        files: [],
        id: row['id'],
        language: row['language'],
        artists: row['artist'] == null
            ? null
            : (json.decode(row['artist']) as List<dynamic>)
                .map((e) => e as String)
                .map((e) => Artist(artist: e))
                .toList(),
        groups: row['groupes'] == null
            ? null
            : (json.decode(row['groupes']) as List<dynamic>)
                .map((e) => e as String)
                .map((e) => Group(group: e))
                .toList(),
        parodys: row['series'] == null
            ? null
            : (json.decode(row['series']) as List<dynamic>)
                .map((e) => e as String)
                .map((e) => Parody(parody: e))
                .toList(),
        characters: row['character'] == null
            ? null
            : (json.decode(row['character']) as List<dynamic>)
                .map((e) => e as String)
                .map((e) => Character(character: e))
                .toList(),
        tags: row['tag'] == null
            ? null
            : (json.decode(row['tag']) as Map<String, dynamic>)
                .map((key, value) => MapEntry(
                    key, (value as List<dynamic>).map((e) => e as String)))
                .entries
                .fold(
                    <Tag>[],
                    (previousValue, element) => previousValue!
                      ..addAll(element.value
                          .map((e) => fromString(element.key, e) as Tag))),
        downDate: row['date'],
        galleryurl: '/${row['type']}/${row['title']}-${row['id']}.html');
    return gallery;
  }

  factory Gallery.fromMap(Map<String, dynamic> data) => Gallery(
        artists: (data['artists'] as List<dynamic>?)
            ?.map((e) => Artist.fromMap(e as Map<String, dynamic>))
            .toList(),
        tags: (data['tags'] as List<dynamic>?)
            ?.map((e) => Tag.fromMap(e as Map<String, dynamic>))
            .toList(),
        sceneIndexes: data['scene_indexes'] as List<dynamic>?,
        japaneseTitle: data['japanese_title'] as String?,
        languages: (data['languages'] as List<dynamic>?)
            ?.map((e) => Language.fromMap(e as Map<String, dynamic>))
            .toList(),
        type: data['type'] as String,
        languageLocalname: data['language_localname'] as String?,
        title: data['title'] as String,
        language: data['language'] as String?,
        characters: (data['characters'] as List<dynamic>?)
            ?.map((e) => Character.fromMap(e as Map<String, dynamic>))
            .toList(),
        galleryurl: data['galleryurl'] as String?,
        languageUrl: data['language_url'] as String?,
        date: data['date'] as String,
        related:
            (data['related'] as List<dynamic>?)?.map((e) => e as int).toList(),
        video: data['video'] as dynamic,
        parodys: (data['parodys'] as List<dynamic>?)
            ?.map((e) => Parody.fromMap(e as Map<String, dynamic>))
            .toList(),
        videofilename: data['videofilename'] as dynamic,
        files: (data['files'] as List<dynamic>)
            .map((e) => Image.fromMap(e as Map<String, dynamic>))
            .toList(),
        id: data['id'] is int ? data['id'] : int.parse(data['id']),
        groups: (data['groups'] as List<dynamic>?)
            ?.map((e) => Group.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'artists': artists?.map((e) => e.toMap()).toList(),
        'tags': tags?.map((e) => e.toMap()).toList(),
        'scene_indexes': sceneIndexes,
        'japanese_title': japaneseTitle,
        'languages': languages?.map((e) => e.toMap()).toList(),
        'type': type,
        'language_localname': languageLocalname,
        'title': title,
        'language': language,
        'characters': characters?.map((e) => e.toMap()).toList(),
        'galleryurl': galleryurl,
        'language_url': languageUrl,
        'date': date,
        'related': related,
        'video': video,
        'parodys': parodys?.map((e) => e.toMap()).toList(),
        'videofilename': videofilename,
        'files': files.map((e) => e.toMap()).toList(),
        'id': id,
        'groups': groups?.map((e) => e.toMap()).toList(),
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Gallery].
  factory Gallery.fromJson(String data) {
    var jsonData = json.decode(data);
    if (jsonData is String) {
      jsonData = json.decode(jsonData);
    }
    return Gallery.fromMap(jsonData as Map<String, dynamic>);
  }

  @override
  String urlEncode({SortEnum? sort}) {
    return '/$type/${Uri.encodeComponent(name.toLowerCase())}-$id.html';
  }

  /// `dart:convert`
  ///
  /// Converts [Gallery] to a JSON string.
  String toJson() => json.encode(toMap());

  Gallery copyWith({
    List<Artist>? artists,
    List<Tag>? tags,
    List<dynamic>? sceneIndexes,
    String? japaneseTitle,
    List<Language>? languages,
    String? type,
    String? languageLocalname,
    String? title,
    String? language,
    List<Character>? characters,
    String? galleryurl,
    String? languageUrl,
    String? date,
    List<int>? related,
    dynamic video,
    List<Parody>? parodys,
    dynamic videofilename,
    List<Image>? files,
    required id,
    List<Group>? groups,
  }) {
    return Gallery(
      artists: artists ?? this.artists,
      tags: tags ?? this.tags,
      sceneIndexes: sceneIndexes ?? this.sceneIndexes,
      japaneseTitle: japaneseTitle ?? this.japaneseTitle,
      languages: languages ?? this.languages,
      type: type ?? this.type,
      languageLocalname: languageLocalname ?? this.languageLocalname,
      title: title ?? this.title,
      language: language ?? this.language,
      characters: characters ?? this.characters,
      galleryurl: galleryurl ?? this.galleryurl,
      languageUrl: languageUrl ?? this.languageUrl,
      date: date ?? this.date,
      related: related ?? this.related,
      video: video ?? this.video,
      parodys: parodys ?? this.parodys,
      videofilename: videofilename ?? this.videofilename,
      files: files ?? this.files,
      id: id,
      groups: groups ?? this.groups,
    );
  }

  String get dirName {
    return '${(artists?.isNotEmpty ?? false) ? '(${artists!.first.name})' : ''}${name}';
  }

  Directory createDir(String outPath,
      {bool createDir = true, bool withArtist = true}) {
    String fullName = join(
        outPath,
        illegalCode.entries.fold(
            withArtist ? dirName : name,
            (previousValue, element) =>
                previousValue!.replaceAll(element.key, element.value)));
    var userName = fullName.substring(0, min(fullName.length, 256)).trim();
    if (userName.endsWith('.')) {
      userName = userName.substring(0, userName.length - 1);
    }
    var dir = Directory(userName);
    if (createDir) {
      dir.createSync();
    }
    return dir;
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Gallery) return false;
    if ((artists == null) ^ (other.artists == null)) {
      return false;
    }
    if (artists != null) {
      return nameFixed == other.nameFixed && artists!.equals(other.artists!);
    }
    return nameFixed == other.nameFixed;
  }

  @override
  int get hashCode => artists.hashCode ^ name.hashCode;

  @override
  String get name {
    var realName = (japaneseTitle ?? title)
        .replaceAll("(Decensored)", '')
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    return realName.where((s) => zhAndJpCodeExp.matchAsPrefix(s)!=null).firstOrNull ??
        realName.first;
  }

  String get nameFixed {
    return titleFixed(name);
  }
}
