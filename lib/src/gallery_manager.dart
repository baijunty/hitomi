import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/group.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/parody.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import 'dhash.dart';

class GalleryManager {
  final UserContext context;
  final SendPort? port;
  late ArgParser parser;
  GalleryManager(this.context, [this.port]) {
    parser = ArgParser()
      ..addFlag('fix')
      ..addFlag('fixDb', abbr: 'f')
      ..addFlag('scan', abbr: 's')
      ..addOption('del')
      ..addOption('add', abbr: 'a')
      ..addMultiOption('tags', abbr: 't')
      ..addCommand(
          'tag',
          ArgParser()
            ..addOption('type', abbr: 't')
            ..addOption('name', abbr: 'n'));
  }
  Future<List<GalleryInfo>> listInfo([String? path]) async {
    var userPath = '${context.outPut}/${path ?? ''}';
    Directory d = Directory(userPath);
    await context.initData();
    final result = await d
        .list()
        .where((event) => event is Directory)
        .map((event) => GalleryInfo.formDirect(event as Directory, context))
        .toList();
    final brokens = <GalleryInfo>[];
    for (var element in result) {
      await element.generalInfo();
      if (element.hash == 0) {
        element.directory.deleteSync(recursive: true);
        brokens.add(element);
      }
    }
    brokens.forEach((element) {
      result.remove(element);
    });
    print('dir size ${result.length} broken ${brokens.length}');
    return result;
  }

  Future<bool> parseCommandAndRun(String cmd) async {
    bool error = false;
    var words = cmd.split(blankExp);
    final args = <String>[];
    bool markCollct = false;
    final markWords = <String>[];
    for (var word in words) {
      if (word.startsWith("'") || word.startsWith("\"")) {
        error = markCollct;
        if (!error) {
          markCollct = true;
          markWords.clear();
          markWords.add(word.substring(1, word.length));
        }
      } else if (word.endsWith("'") || word.endsWith("\"")) {
        if (markCollct) {
          markWords.add(word.substring(0, word.length - 1));
          args.add(markWords.join(' '));
          markWords.clear();
          markCollct = false;
        } else {
          args.add(word);
        }
      } else if (markCollct) {
        markWords.add(word);
      } else {
        args.add(word);
      }
    }
    if (markCollct) {
      print(parser.usage);
      return false;
    }
    final result = parser.parse(args);
    if (result['scan']) {
      await listInfo();
    } else if (result.wasParsed('add') || numberExp.hasMatch(cmd)) {
      String id = numberExp.hasMatch(cmd) ? cmd : result['add'];
      error = !numberExp.hasMatch(id);
      if (!error) {
        error = !await downLoadGallery(id.toInt());
      }
    } else if (result.wasParsed('del')) {
      String id = result['del'];
      error = !numberExp.hasMatch(id);
      if (!error) {
        delGallery(id.toInt());
      }
    } else if (result.command != null || result.wasParsed('tags')) {
      var name = result.command?['name'];
      var type = result.command?['type'];
      List<String> tagWords = result.wasParsed('tags') ? result['tags'] : [];
      error = name == null && tagWords.isEmpty;
      if (!error) {
        List<Lable> tags = [];
        if (type != null) {
          tags.add(fromString(type, name));
        } else if (name != null) {
          tagWords.add(name);
        }
        tags.addAll(tagWords.map((e) => context.helper.getLableFromKey(e)));
        tags.addAll(context.languages);
        print('$cmd parse result $tags');
        await downLoadByTag(
            tags,
            (gallery) =>
                DateTime.parse(gallery.date).compareTo(context.limit) > 0 &&
                (gallery.artists?.length ?? 0) <= 2 &&
                gallery.files.length >= 18);
      }
    } else if (result['fixDb']) {
      await fixDb();
    } else if (result['fix']) {
      await fix();
    }
    if (error) {
      print(parser.usage);
    }
    return !error;
  }

  Future<bool> downLoadGallery(int id) async {
    var lastDate = DateTime.now();
    return await context.api.downloadImagesById(id, onProcess: (msg) {
      var now = DateTime.now();
      if (now.difference(lastDate).inMilliseconds > 300) {
        lastDate = now;
        this.port?.send(msg);
      }
    });
  }

  Future<bool> downLoadByTag(
      List<Lable> tags, bool where(Gallery gallery)) async {
    final api = context.api;
    final results =
        await api.search(tags, exclude: context.exclude).then((value) async {
      return await Stream.fromIterable(value)
          .asyncMap((event) async => await api.fetchGallery(event))
          .where((event) => where(event))
          .asyncMap((event) async {
        final img = await api.downloadImage(
            event.files.first.getThumbnailUrl(context),
            'https://hitomi.la${Uri.encodeFull(event.galleryurl!)}');
        var hash = await imageHash(Uint8List.fromList(img));
        return Tuple2(hash, event);
      }).fold<Map<int, Gallery>>({}, (previousValue, element) {
        previousValue.removeWhere((key, value) {
          if (compareHashDistance(key, element.item1) < 8 &&
              (element.item2.language == 'japanese' ||
                  element.item2.language == value.language)) {
            return true;
          }
          return false;
        });
        previousValue[element.item1] = element.item2;
        return previousValue;
      });
    });
    bool b = true;
    print('find length ${results.length}');
    for (var element in results.entries) {
      b &= await api.downloadImagesById(element.value.id.toInt());
    }
    return b;
  }

  Future<void> delBackUp() async {
    await Directory('${context.outPut}/sdfsdfdf')
        .list()
        .where((event) => event is Directory)
        .map((event) => GalleryInfo.formDirect(event as Directory, context))
        .forEach((element) async {
      if (element.directory.listSync().isEmpty) {
        print('del empty ${element.directory.path}');
        element.directory.deleteSync(recursive: true);
      } else {
        await element.computeHash();
        if (element.hash == 0) {
          print('del broken ${element.directory.path}');
          element.directory.deleteSync(recursive: true);
        }
        var set = context.helper
            .querySql('select * from Gallery where hash=?', [element.hash]);
        if (set?.isNotEmpty ?? false) {
          print(
              'del duplicate ${element.directory.path} with ${set!.first['title']}');
          element.directory.deleteSync(recursive: true);
        }
        print('$element is safe? ${element.directory.existsSync()}');
      }
    });
  }

  Future<bool> fix() async {
    Map<int, List<GalleryInfo>> result = await listInfo()
        .then((value) =>
            value.fold<Map<int, List<GalleryInfo>>>({}, ((previous, element) {
              final list = previous[element.hash] ?? [];
              list.add(element);
              previous[element.hash] = list;
              return previous;
            })))
        .catchError((e) {
      print(e);
      throw e;
    });
    result.entries.where((element) => element.value.length > 1).forEach((ele) {
      final value = ele.value;
      value.reduce((key, element) {
        final reletion = key.relationToOther(element);
        print('$key and ${element} is $reletion');
        switch (reletion) {
          case Relation.Same:
            if (!key.fromHitomi) {
              key.directory.deleteSync(recursive: true);
            } else {
              element.directory.deleteSync(recursive: true);
            }
            break;
          case Relation.DiffChapter:
            // if (element.chapter.length > key.chapter.length) {
            //   key.directory
            //       .rename(this.context.outPut + '/backup/' + key.title);
            // } else {
            //   element.directory
            //       .rename(this.context.outPut + '/backup/' + element.title);
            // }
            break;
          case Relation.DiffSource:
            // if (!key.fromHitomi) {
            //   safeRename(key.directory);
            // } else {
            //   safeRename(element.directory);
            // }
            break;
          case Relation.UnRelated:
            break;
        }
        return key.directory.existsSync() ? key : element;
      });
    });
    print('result size ${result.length}');
    return true;
  }

  Future<bool> fixDb() async {
    var set = context.helper
        .querySql('select id,path from Gallery')
        ?.whereNot((element) => Directory(element['path']).existsSync());
    if (set != null) {
      for (var row in set) {
        print('fix $row');
        await context.api.downloadImagesById(row['id']);
      }
    }
    return set != null && set.isNotEmpty;
  }

  void delGallery(int id) {
    context.helper.excuteSql('delete from Gallery where id=?', [id]);
  }
}

Future<void> safeRename(FileSystemEntity from, [String? to]) async {
  String target = to ?? '${from.parent.path}/sdfsdfdf/${basename(from.path)}';
  try {
    if (from.path == target) {
      return;
    }
    var newFile = File(target).statSync();
    if (newFile.type == FileSystemEntityType.notFound) {
      await from.rename(target);
    } else {
      from.deleteSync(recursive: true);
    }
  } catch (e) {
    print(' rename with $e and $target exists ${File(target).existsSync()}');
  }
}

class GalleryInfo {
  late String title;
  Set<int> chapter = {};
  late int hash;
  late File metaFile;
  bool fromHitomi = false;
  SqliteHelper get helper => context.helper;
  static final _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static final _numberChap = RegExp(r'((?<start>\d+)-)?(?<end>\d+)話?$');
  static final _fileNumber = RegExp(r'(?<num>\d+)\.\w+$');
  static final _ehTitleReg = RegExp(
      r'(\((?<event>.+?)\))?\s*\[(?<group>.+?)\s*(\((?<author>.+?)\))?\]\s*(?<name>.*)$');
  static final _serialExp = RegExp(r'(?<title>.+?)(?<serial>\(.+\))?$');
  static final _additionExp = RegExp(r'(?<name>.+?)(?<addition>\[.+?\])?$');
  static final _hitomiTitleExp = RegExp(r'(\((?<author>.+?)\))(?<title>.+)$');
  static final _numberTitle = RegExp(r'^-?\d+$');
  Directory directory;
  UserContext context;
  late Hitomi api;
  GalleryInfo.formDirect(this.directory, this.context) {
    this.title = basename(directory.path);
    metaFile = File(directory.path + '/meta.json');
    fromHitomi = metaFile.existsSync();
    api = Hitomi.fromPrefenerce(context);
  }

  Future<void> generalInfo() async {
    await _tryGetGalleryInfo();
  }

  Future<void> searchFromHitomi(List<Lable> tags) async {
    await computeHash();
    tags.addAll(
        context.languages.fold<List<Lable>>([], (acc, i) => acc..add(i)));
    print('search for  $tags');
    var gallery = this.hash == 0
        ? null
        : await api.search(tags, exclude: context.exclude).then((value) async {
            print('result length ${value.length}');
            if (value.length > 50) {
              return null;
            }
            final firstId = await Stream.fromIterable(value)
                .asyncMap((element) async =>
                    await api.fetchGallery(element, usePrefence: false))
                .asyncMap((value) async {
              int hash1 = await api
                  .downloadImage(value.files.first.getThumbnailUrl(context),
                      'https://hitomi.la${Uri.encodeFull(value.galleryurl!)}')
                  .then((value) => imageHash(Uint8List.fromList(value)));
              final distance = compareHashDistance(hash1, this.hash);
              print(
                  '${value.name} ${value.id} $hash1 and ${this.hash} distance $distance');
              if (distance < 8) {
                return value;
              }
              return null;
            }).firstWhere((element) => element != null, orElse: () => null);
            return firstId == null
                ? null
                : await api.fetchGallery(firstId.id.toInt());
          }).catchError((e) async => null);
    bool success = gallery != null;
    if (success) {
      final target = '${context.outPut}/${gallery.fixedTitle}';
      await safeRename(directory, target);
      directory = Directory(target);
      final files = gallery.files
          .where((element) =>
              numberExp.hasMatch(basenameWithoutExtension(element.name)))
          .map((e) => e.name)
          .toList();
      directory
          .list()
          .where((element) =>
              numberExp.hasMatch(basenameWithoutExtension(element.path)))
          .forEach((element) {
        final number = basenameWithoutExtension(element.path).toInt();
        final exists = files.firstWhereOrNull(
            (element) => basenameWithoutExtension(element).toInt() == number);
        if (exists != null) {
          safeRename(element, '$target/$exists');
        }
      });
      success = await api.downloadImagesById(int.parse(gallery.id),
          usePrefence: false);
      if (success) {
        await _hitomiParse(gallery);
      }
    } else {
      await safeRename(directory);
    }
    return null;
  }

  Future<void> computeHash([File? img]) async {
    if (img == null) {
      final files = await directory.list().where((event) {
        final name = basename(event.path);
        return _imageExtensions.contains(extension(name));
      }).toList();
      files.sortBy<num>((element) {
        final name = basenameWithoutExtension(element.path);
        final numValue = RegExp(r'\d+').allMatches(name).fold<num>(
            0,
            (previousValue, element) =>
                previousValue +
                name.substring(element.start, element.end).toInt());
        return numValue;
        // return int.parse(
        //     _fileNumber.firstMatch(element.path)!.namedGroup('num')!);
      });
      img = files.firstOrNull as File?;
      print('use $img to hash');
    }
    this.hash = await img
            ?.readAsBytes()
            .then((value) => imageHash(value))
            .catchError((e) {
          final code = runPython(img!.path);
          if (code.isNotEmpty && !code.toLowerCase().startsWith('no')) {
            return List.generate(code.length ~/ 2,
                    (index) => code.substring(index * 2, index * 2 + 2))
                .map((e) => int.parse(e, radix: 16))
                .foldIndexed<int>(
                    0,
                    (index, previousValue, element) =>
                        previousValue | element << (7 - index) * 8);
          }
          return 0;
        }) ??
        0;
  }

  String runPython(String target) {
    return Process.runSync('python3', ['test/encode.py', target]).stdout
        as String;
  }

  void insertToDataBase(Gallery gallery) {
    helper.excuteWithRow(
        'replace into Gallery(id,path,author,groupes,serial,language,title,tags,files,hash) values(?,?,?,?,?,?,?,?,?,?)',
        (statement) {
      statement.execute([
        gallery.id,
        directory.path,
        gallery.artists?.first.translate,
        gallery.groups?.first.translate,
        gallery.parodys?.first.translate,
        gallery.language,
        gallery.name,
        json.encode(gallery.lables().map((e) => e.index).toList()),
        json.encode(gallery.files.map((e) => e.name).toList()),
        hash
      ]);
    });
  }

  Future<void> _tryGetGalleryInfo() async {
    if (fromHitomi) {
      return await metaFile.readAsString().then((value) {
        try {
          return Gallery.fromJson(value);
        } catch (e) {
          return Gallery.fromJson(runPython(metaFile.path));
        }
      }).then((value) async => await _hitomiParse(value));
    } else if (_ehTitleReg.hasMatch(title)) {
      print('eh analyisis ${title}');
      await _ehTitleParse(title);
    } else if (_numberTitle.hasMatch(title)) {
      this.hash = 0;
      await safeRename(directory);
    } else if (_hitomiTitleExp.hasMatch(title)) {
      print('hitomi analyisis ${title}');
      var mathces = _hitomiTitleExp.firstMatch(title)!;
      var author = mathces.namedGroup('author');
      List<Lable> tags = [];
      if (author != null) {
        tags.add(Artist(artist: author));
      }
      _chapterParse(title);
      title = mathces.namedGroup('title')!;
      tags.addAll(title
          .split(blankExp)
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .map((e) => zhAndJpCodeExp
              .allMatches(e)
              .map((exp) => e.substring(exp.start, exp.end)))
          .fold<List<String>>(
              [],
              (previousValue, element) => previousValue
                ..addAll(element.toList())).map((e) => QueryText(e)));
      await searchFromHitomi(tags);
    } else if (_serialExp.hasMatch(title)) {
      print('serial analyisis ${title}');
      if (_additionExp.hasMatch(title)) {
        title = _additionExp.firstMatch(title)!.namedGroup('name')!.trim();
      }
      var mathces = _serialExp.firstMatch(title)!;
      var serial = mathces.namedGroup('serial');
      this.title = title.substring(0, title.length - (serial?.length ?? 0));
      List<Lable> tags = [];
      tags.addAll(title
          .split(blankExp)
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .map((e) => zhAndJpCodeExp
              .allMatches(e)
              .map((exp) => e.substring(exp.start, exp.end)))
          .fold<List<String>>(
              [],
              (previousValue, element) => previousValue
                ..addAll(element.toList())).map((e) => QueryText(e)));
      await searchFromHitomi(tags);
    } else {
      return await searchFromHitomi(title
          .split(blankExp)
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .map((e) => QueryText(e))
          .fold<List<Lable>>([], (acc, i) => acc..add(i)));
    }
  }

  Future<void> _hitomiParse(Gallery value) async {
    title = value.name.trim();
    _chapterParse(title);
    await checkFilesExists(value);
    final result =
        helper.querySql('select hash from Gallery where id =?', [value.id]);
    if (result?.isNotEmpty ?? false) {
      hash = result!.first['hash'];
      return;
    }
    if (value.fixedTitle != basename(this.directory.path)) {
      final newDir = Directory(context.outPut + "/" + value.fixedTitle);
      if (!newDir.existsSync()) {
        await safeRename(directory, newDir.path);
      } else {
        await safeRename(directory);
      }
      directory = newDir;
    }
    value.translateLable(helper);
    await computeHash(File(directory.path + '/${value.files.first.name}'));
    insertToDataBase(value);
  }

  Future<void> checkFilesExists(Gallery gallery) async {
    var files = gallery.files.map((e) => e.name).toList();
    await directory.list().where((event) {
      final name = basename(event.path);
      return !name.endsWith('json') && !files.contains(name);
    }).forEach((element) {
      element.deleteSync();
    });
    final mission = files
        .map((e) => File(directory.path + '/' + e))
        .firstWhereOrNull((element) {
      return !element.existsSync();
    });
    if (mission != null) {
      print('mission $mission');
      await api.downloadImagesById(gallery.id.toInt(), usePrefence: false);
    }
  }

  String? _tryTransLateFromJp(String name) {
    return helper.querySql(
        'select * from Tags WHERE translate=?', [name])?.firstOrNull?['name'];
  }

  Future<void> _ehTitleParse(String name) async {
    name = name.substring(name.indexOf('['));
    List<Lable> tags = [];
    var mathces = _ehTitleReg.firstMatch(name)!;
    var group = mathces.namedGroup('group');
    String? translate = null;
    if (group != null && (translate = _tryTransLateFromJp(group)) != null) {
      tags.add(Group(group: translate!));
    }
    var author = mathces.namedGroup('author');
    if (author != null && (translate = _tryTransLateFromJp(author)) != null) {
      tags.add(Artist(artist: translate!));
    }
    var left = mathces.namedGroup('name')!;
    if (_additionExp.hasMatch(left)) {
      left = _additionExp.firstMatch(left)!.namedGroup('name')!.trim();
    }
    if (_serialExp.hasMatch(left)) {
      mathces = _serialExp.firstMatch(left)!;
      var serial = mathces.namedGroup('serial');
      this.title = left.substring(0, left.length - (serial?.length ?? 0));
      if (serial != null && (translate = _tryTransLateFromJp(serial)) != null) {
        tags.add(Parody(parody: translate!));
      }
    }
    tags.addAll(title
        .split(blankExp)
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .map((e) => zhAndJpCodeExp
            .allMatches(e)
            .map((exp) => e.substring(exp.start, exp.end)))
        .fold<List<String>>(
            [],
            (previousValue, element) => previousValue
              ..addAll(element.toList())).map((e) => QueryText(e)));
    _chapterParse(title);
    return searchFromHitomi(tags);
  }

  void _chapterParse(String name) {
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
    if (0 == this.hash || 0 == other.hash) {
      return Relation.UnRelated;
    }
    int distance = compareHashDistance(this.hash, other.hash);
    if (this.title != other.title) {
      distance += 3;
    }
    if (chapter.compareTo(other.chapter) != 0) {
      print('${directory.path} $chapter is diff to ${other.chapter}');
      return Relation.DiffChapter;
    }
    if (distance < 12) {
      return Relation.Same;
    }
    return Relation.UnRelated;
  }

  @override
  String toString() {
    return '$title-$hash';
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! GalleryInfo) return false;
    return relationToOther(other) == Relation.Same;
  }

  @override
  int get hashCode => title.hashCode;
}

enum Relation { Same, DiffChapter, DiffSource, UnRelated }
