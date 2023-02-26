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

  Future<bool> fix() async {
    Map<GalleryInfo, List<GalleryInfo>> result = await listInfo()
        .fold<Map<GalleryInfo, List<GalleryInfo>>>({}, ((previous, element) {
      final list = previous[element] ?? [];
      list.add(element);
      previous[element] = list;
      return previous;
    }));
    result.forEach((key, value) {
      print('$key and ${value.length}');
      value.forEach((element) {
        final reletion = key.relationToOther(element);
        switch (reletion) {
          case Relation.Same:
            if (element.length > key.length) {
              key.directory.rename(r'\\192.168.3.228\ssd\music');
            } else {
              element.directory.rename(r'\\192.168.3.228\ssd\music');
            }
            break;
          case Relation.DiffChapter:
            if (element.chapter.length > key.chapter.length) {
              key.directory.rename(r'\\192.168.3.228\ssd\music');
            } else {
              element.directory.rename(r'\\192.168.3.228\ssd\music');
            }
            print('$key and ${element} is diffrence chapter');
            break;
          case Relation.DiffSource:
            if (element.translated) {
              element.directory.rename(r'\\192.168.3.228\ssd\music');
            } else {
              key.directory.rename(r'\\192.168.3.228\ssd\music');
            }
            break;
          case Relation.UnRelated:
            print('$key and ${element} is diffrence');
            break;
        }
      });
    });
    return true;
  }
}

class GalleryInfo {
  String? author;
  String? group;
  String? serial;
  bool translated = false;
  int? id;
  bool realTitle = true;
  late String title;
  Set<int> chapter = {1};
  late int hash;
  late int length;
  static final _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static final _numberChap = RegExp(r'((?<start>\d+)-)?(?<end>\d+)話?$');
  static final _ehTitleReg = RegExp(
      r'(\((?<event>.+?)\))?\s*\[(?<group>.+?)\s*(\((?<author>.+?)\))?\]\s*(?<name>.*)$');
  static final serialExp =
      RegExp(r'(?<title>.+?)(\((?<serial>.+?)\))?(\[(?<addition>.+?)\])?$');
  bool get isEmpty => length == 0;
  final Directory directory;
  SqliteHelper helper;
  GalleryInfo.formDirect(this.directory, this.helper) {
    this.title = basename(directory.path);
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
      this.hash = await (img as File)
          .readAsBytes()
          .then((value) => imageHash(value))
          .then((value) => value.foldIndexed<int>(0,
              (index, acc, element) => acc |= element ? 1 << (63 - index) : 0));
      this.length = files.length;
    }
    var metaFile = File(directory.path + '/meta.json');
    if (metaFile.existsSync()) {
      await metaFile.readAsString().then((value) async {
        try {
          return Gallery.fromJson(value);
        } catch (e) {
          print('$directory has $e');
          final r = Process.runSync('python', ['test/hash.py', metaFile.path]);
          print('result ${r.stdout} err ${r.stderr}');
          final gallery = Gallery.fromJson(metaFile.readAsStringSync());
          print('now fixed $directory');
          return gallery;
        }
      }).then((value) {
        author = value.artists?.firstOrNull?.artist;
        group = value.groups?.first.name;
        serial = value.parodys?.first.name;
        translated = value.language != 'japanese';
        title = value.name.trim();
        chapterParse(title);
      });
    } else if (_ehTitleReg.hasMatch(title)) {
      ehTitleParse(title);
    }
    if (RegExp(r'^-?\d+$').hasMatch(title)) {
      realTitle = author != null;
    }
  }

  Future<void> ehTitleParse(String name) async {
    name = name.substring(name.indexOf('['));
    var mathces = _ehTitleReg.firstMatch(name)!;
    this.group = mathces.namedGroup('group');
    this.author = mathces.namedGroup('author');
    var left = mathces.namedGroup('name')!;
    if (serialExp.hasMatch(left)) {
      mathces = serialExp.firstMatch(left)!;
      this.title = mathces.namedGroup('title')!.trim();
      serial = mathces.namedGroup('serial');
      String lang = mathces.namedGroup('addition') ?? '';
      translated = lang.contains('翻訳') ||
          lang.contains('汉化') ||
          lang.contains('中文') ||
          lang.contains('中国');
    }
    chapterParse(title);
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

  Relation relationToOther(GalleryInfo other) {
    int hashXor = this.hash ^ other.hash;
    if (hashXor == this.hash) {
      return Relation.UnRelated;
    }
    if (other.realTitle && realTitle) {}
    int distance = 0;
    while (hashXor > 0) {
      if (hashXor & 1 == 1) distance++;
      hashXor >>= 1;
    }
    if (realTitle && other.realTitle) {
      if (this.title != other.title) {
        distance += 4;
      } else if ((author ?? '') != (other.author ?? '')) {
        distance += 4;
      } else if (chapter != other.chapter) {
        return Relation.DiffChapter;
      }
    }
    if (distance < 12) {
      if (translated ^ other.translated) {
        return Relation.DiffSource;
      }
      return Relation.Same;
    }
    return Relation.UnRelated;
  }

  @override
  String toString() {
    return '[$author($group)]$title($serial)${chapter.join()}-$hash';
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! GalleryInfo) return false;
    return title == other.title && (author ?? '') == (other.author ?? '');
  }
}

enum Relation { Same, DiffChapter, DiffSource, UnRelated }
