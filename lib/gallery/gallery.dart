import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:logger/logger.dart';

import 'artist.dart';
import 'character.dart';
import 'image.dart';
import 'group.dart';
import 'language.dart';
import 'parody.dart';
import 'tag.dart';

class Gallery with Lable {
  static final zhNum = '零〇一二三四五六七八九十';
  static final chapterRex = RegExp(
      r'第?\s*(?<start>[零〇一二三四五六七八九十|\d]{1,})\s*-?\s*(?<end>[零〇一二三四五六七八九十|\d]*)\s*(?<unit>[章|回|话|話|編|巻|集]*)');
  static const List<String> illegalCode = [
    r'\',
    '/',
    '*',
    ':',
    '?',
    '"',
    '<',
    '>',
    '|',
    '.',
  ];
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
  final List<int>? related;
  final String? video;
  final List<Parody>? parodys;
  final String? videofilename;
  final List<Image> files;
  final id;
  final List<Group>? groups;

  Gallery({
    this.artists,
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
  });

  List<Lable> lables() {
    return <Lable>[]
      ..addAll(artists ?? [])
      ..addAll(tags ?? [])
      ..addAll(characters ?? [])
      ..addAll(parodys ?? [])
      ..addAll(groups ?? []);
  }

  @override
  String toString() {
    return 'Gallery(type: $type, title: ${dirName}, language: $language, date: $date, id: $id)';
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
        id: data['id'],
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

  /// `dart:convert`
  ///
  /// Converts [Gallery] to a JSON string.
  String toJson() => json.encode(toMap());

  bool tagIlleagal(List<String> excludes, [Logger? logger = null]) {
    var illeagalTags =
        tags?.where((element) => excludes.contains(element.name)).toList() ??
            [];
    final count = illeagalTags.length;
    if (count > 0) {
      logger?.i('found $tags');
    }
    return count * 20 / (files.length) > 0.5;
  }

  List<int> chapter() {
    final matcher = chapterRex.allMatches(name).toList();
    if (matcher.isNotEmpty) {
      final last = matcher.last;
      var start = last.namedGroup('start');
      final digit = start!.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
          start.codeUnitAt(0) <= '9'.codeUnitAt(0);
      final atEnd = name.substring(last.end).isEmpty;
      if (digit && atEnd) {
        var chapters = <int>[];
        var end = last.namedGroup('end') ?? start;
        end = end.isNotEmpty ? end : start;
        var from = int.parse(start);
        for (var i = from; i <= int.parse(end); i++) {
          chapters.add(i);
        }
        return chapters;
      } else if (atEnd && start.length == 1) {
        var chapters = <int>[];
        var from = start.codeUnits
            .map((e) => String.fromCharCode(e))
            .map((e) => zhNum.indexOf(e) - 1)
            .first;
        var end = last.namedGroup('end') ?? start;
        end = end.length == 1 ? end : start;
        final to = end.codeUnits
            .map((e) => String.fromCharCode(e))
            .map((e) => zhNum.indexOf(e) - 1)
            .first;
        for (var i = from; i <= to; i++) {
          chapters.add(i);
        }
        return chapters;
      }
    }
    return [];
  }

  bool chapterContains(Gallery other) {
    var chapters1 = chapter();
    var chapters2 = other.chapter();
    if (chapters1.length < chapters2.length) {
      return false;
    }
    var same = (chapters1.isEmpty ^ chapters2.isEmpty) == false;
    if (same && chapters1.isNotEmpty) {
      chapters2.removeWhere((element) => chapters1.contains(element));
      return chapters2.isEmpty;
    }
    return same;
  }

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
    var direct =
        '${(artists?.isNotEmpty ?? false) ? '(${artists!.first.name})' : ''}${name}';
    return illegalCode.where((e) => direct.contains(e)).fold<String>(direct,
        (previousValue, element) => previousValue.replaceAll(element, ''));
  }

  Directory createDir(String outPath) {
    Directory dir;
    try {
      dir = Directory("${outPath}/${dirName}")..createSync();
    } catch (e) {
      dir = Directory(
          "${outPath}/${artists?.isNotEmpty ?? false ? '' : '(${artists!.first.name})'}$id")
        ..createSync();
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
  String get name => (japaneseTitle ?? title).replaceAll("(Decensored)", '');

  String get nameFixed {
    final matcher = chapterRex.allMatches(name).toList();
    if (matcher.isNotEmpty) {
      final last = matcher.last;
      final atEnd = name.substring(last.end).isEmpty;
      if (atEnd) {
        return name.substring(0, last.start);
      }
    }
    return name;
  }
}
