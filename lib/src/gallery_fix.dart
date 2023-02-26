import 'dart:io';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:path/path.dart';

import 'dhash.dart';
import 'prefenerce.dart';

class GalleryFix {
  final UserContext context;
  GalleryFix(this.context);
  Stream<GalleryInfo> listInfo() async* {
    Directory d = Directory(context.outPut);
    await for (var element in d
        .list()
        .takeWhile((event) => event is Directory)
        .map((event) =>
            GalleryInfo.formDirect(event as Directory, context.helper))) {
      await element.computeData();
      yield element;
    }
  }
}

class GalleryInfo {
  String? author;
  String? group;
  String? serial;
  bool translated = false;
  int? id;
  late String title;
  List<int> chapter = const [];
  late int hash;
  late int length;
  static final _imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static final _numberChap = RegExp(r'((?<start>\d+)-)?(?<end>\d+)話?$');
  static final _ehTitleReg = RegExp(
      r'^\((?<event>.+?)\)?\s*\[(?<author>.+?)\s*(\((?<group>.+?)\))?\]\s*(?<name>.*)$');
  static final serialExp =
      RegExp(r'(?<title>.+?)(\((?<serial>.+?)\))?(\[(?<addition>.+?)\])?$');
  bool get isEmpty => length == 0;
  final Directory directory;
  SqliteHelper helper;
  GalleryInfo.formDirect(this.directory, this.helper) {
    this.title = dirname(directory.path);
  }

  Future<void> computeData() async {
    final files = directory.listSync();
    final img = files.firstWhere(
        (element) =>
            _imageExtensions.contains(extension(element.path).toLowerCase()),
        orElse: () => directory);
    if (img == directory) {
      this.hash = 0;
      this.length = 0;
    } else {
      this.hash = await File(img.path)
          .readAsBytes()
          .then((value) => imageHash(value))
          .then((value) => value.foldIndexed<int>(0,
              (index, acc, element) => acc |= element ? 1 << (63 - index) : 0));
      this.length = files.length;
    }
    var metaFile = File(directory.path + '/meta.json');
    if (metaFile.existsSync()) {
      metaFile
          .readAsString()
          .then((value) => Gallery.fromJson(value))
          .then((value) {
        author = value.artists?.firstOrNull?.artist;
        group = value.groups?.first.name;
        serial = value.parodys?.first.name;
        translated = value.language != 'japanese';
        title = value.name;
        chapterParse(value.name);
      });
    } else if (_ehTitleReg.hasMatch(title)) {
      ehTitleParse(title);
    }
  }

  Future<void> ehTitleParse(String name) async {
    var mathces = _ehTitleReg.firstMatch(name)!;
    this.group = mathces.namedGroup('group');
    this.author = mathces.namedGroup('author')!;
    var left = mathces.namedGroup('name')!;
    if (serialExp.hasMatch(left)) {
      mathces = serialExp.firstMatch(left)!;
      this.title = mathces.namedGroup('title')!;
      serial = mathces.namedGroup('serial');
      String lang = mathces.namedGroup('addition') ?? '';
      translated = lang.contains('翻訳') ||
          lang.contains('汉化') ||
          lang.contains('中文') ||
          lang.contains('中国');
    }
    if (author != null) {
      author = tryTranslate('artist', author!);
    }
    if (group != null) {
      group = tryTranslate('group', group!);
    }
    if (serial != null) {
      serial = tryTranslate('parody', group!);
    }
  }

  String tryTranslate(String type, String name) {
    var search = this
        .helper
        .querySql(
            'select name from Tags where type=? and translate=?', [type, name])
        ?.first
        .values[0]
        .toString();
    return search ?? name;
  }

  void chapterParse(String name) {
    if (_numberChap.hasMatch(name)) {
      var matchers = _numberChap.firstMatch(name)!;
      var end = int.parse(matchers.namedGroup('end')!);
      var startCap = matchers.namedGroup('start');
      int start = end;
      if (startCap != null) {
        start = int.tryParse(startCap)!;
      }
      for (var i = start; i <= end; i++) {
        chapter.add(i);
      }
    }
  }

  @override
  String toString() {
    return '[$author($group]$title($serial)${chapter.join()}';
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! GalleryInfo) return false;
    return title == other.title && (author ?? '') == (other.author ?? '');
  }
}
