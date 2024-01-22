import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../gallery/artist.dart';
import '../gallery/gallery.dart';
import '../gallery/group.dart';
import '../gallery/label.dart';
import '../gallery/parody.dart';
import '../lib.dart';
import 'dhash.dart';
import 'sqlite_helper.dart';

class GalleryInfo {
  late String title;
  Set<int> chapter = {};
  late int hash;
  late File metaFile;
  bool fromHitomi = false;
  late SqliteHelper helper;
  static final _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static final _numberChap = RegExp(r'((?<start>\d+)-)?(?<end>\d+)話?$');
  // static final _fileNumber = RegExp(r'(?<num>\d+)\.\w+$');
  static final _ehTitleReg = RegExp(
      r'(\((?<event>.+?)\))?\s*\[(?<group>.+?)\s*(\((?<author>.+?)\))?\]\s*(?<name>.*)$');
  static final _serialExp = RegExp(r'(?<title>.+?)(?<serial>\(.+\))?$');
  static final _additionExp = RegExp(r'(?<name>.+?)(?<addition>\[.+?\])?$');
  static final _hitomiTitleExp = RegExp(r'(\((?<author>.+?)\))(?<title>.+)$');
  static final _numberTitle = RegExp(r'^-?\d+$');
  Directory directory;
  UserConfig config;
  final Hitomi api;
  GalleryInfo.formDirect(this.directory, this.config, this.api) {
    this.title = basename(directory.path);
    metaFile = File(directory.path + '/meta.json');
    fromHitomi = metaFile.existsSync();
    helper = SqliteHelper(config.output);
  }

  Future<Gallery?> searchFromHitomi(List<Lable> tags) async {
    await computeHash();
    tags.addAll(config.languages
        .fold<List<Lable>>([], (acc, i) => acc..add(Language(name: i))));
    print('search for  $tags');
    var gallery = this.hash == 0
        ? null
        : await api
            .search(tags, exclude: await helper.mapToLabel(config.excludes))
            .then((value) async {
            print('result length ${value.length}');
            if (value.length > 50) {
              return null;
            }
            final firstId = await Stream.fromIterable(value)
                .asyncMap((element) async =>
                    await api.fetchGallery(element, usePrefence: false))
                .asyncMap((value) async {
              int hash1 = await api
                  .downloadImage(api.getThumbnailUrl(value.files.first),
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
            return firstId == null ? null : await api.fetchGallery(firstId.id);
          }).catchError((e) async => null);
    bool success = gallery != null;
    if (success) {
      final target = '${config.output}/${gallery.dirName}';
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
      success = await api.downloadImagesById(gallery.id, usePrefence: false);
      if (success) {
        return await _hitomiParse(gallery);
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

  Future<Gallery?> tryGetGalleryInfo() async {
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
      return await _ehTitleParse(title);
    } else if (_numberTitle.hasMatch(title)) {
      this.hash = 0;
      await safeRename(directory);
      return null;
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
      return await searchFromHitomi(tags);
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
      return await searchFromHitomi(tags);
    } else {
      return await searchFromHitomi(title
          .split(blankExp)
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .map((e) => QueryText(e))
          .fold<List<Lable>>([], (acc, i) => acc..add(i)));
    }
  }

  Future<Gallery> _hitomiParse(Gallery value) async {
    title = value.name.trim();
    _chapterParse(title);
    await checkFilesExists(value);
    final result = await helper
        .querySql('select hash from Gallery where id =?', [value.id]);
    if (result?.isNotEmpty ?? false) {
      hash = result!.first['hash'];
      return value;
    }
    if (value.dirName != basename(this.directory.path)) {
      final newDir = Directory(config.output + "/" + value.dirName);
      if (!newDir.existsSync()) {
        await safeRename(directory, newDir.path);
      } else {
        await safeRename(directory);
      }
      directory = newDir;
    }
    await computeHash(File(directory.path + '/${value.files.first.name}'));
    await helper.insertGallery(value, '', hash);
    return value;
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
      await api.downloadImagesById(gallery.id, usePrefence: false);
    }
  }

  Future<String?> _tryTransLateFromJp(String name) async {
    return await helper.querySql('select * from Tags WHERE translate=?',
        [name]).then((value) => value?.firstOrNull?['name']);
  }

  Future<Gallery?> _ehTitleParse(String name) async {
    name = name.substring(name.indexOf('['));
    List<Lable> tags = [];
    var mathces = _ehTitleReg.firstMatch(name)!;
    var group = mathces.namedGroup('group');
    String? translate = null;
    if (group != null &&
        (translate = await _tryTransLateFromJp(group)) != null) {
      tags.add(Group(group: translate!));
    }
    var author = mathces.namedGroup('author');
    if (author != null &&
        (translate = await _tryTransLateFromJp(author)) != null) {
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
      if (serial != null &&
          (translate = await _tryTransLateFromJp(serial)) != null) {
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

  Future<void> delBackUp() async {
    await Directory('${config.output}/sdfsdfdf')
        .list()
        .where((event) => event is Directory)
        .map((event) => GalleryInfo.formDirect(event as Directory, config, api))
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
        var set = await helper
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
    await helper
        .querySql(
            r'''select hash,path,id from Gallery where hash in( select hash from Gallery GROUP by hash  having count(*)  > 1) order by hash''')
        .then((value) => value?.toList().asStream())
        .then((value) async => value
                ?.asyncMap((element) async => Tuple2(
                    element['id'] as int,
                    await GalleryInfo.formDirect(
                            Directory(element['path']), config, api)
                        .tryGetGalleryInfo()))
                .where((event) => event.item1 != event.item2?.id)
                .forEach((element) {
              print('del ${element.item2?.dirName}');
              delGallery(element.item1);
            }))
        .catchError((e) => print(e));
    var set = await helper.querySql('select id,path from Gallery').then(
        (value) => value
            ?.toList()
            .whereNot((element) => Directory(element['path']).existsSync()));
    print('fix $set');
    if (set != null) {
      for (var row in set) {
        print('fix $row');
        var gallery = await api.fetchGallery(row['id']);
        if (gallery.id != row['id']) {
          delGallery(row['id']);
        }
        await api.downloadImagesById(gallery.id);
        helper.insertGallery(gallery, '');
      }
    }
    return set != null && set.isNotEmpty;
  }

  void delGallery(int id) async {
    var set =
        await helper.querySql('select path from Gallery where id=?', [id]);
    print(set);
    set
        ?.mapNonNull((e) => e!['path'])
        .map((event) => File(event))
        .forEach((element) {
      print('del file $element');
      element.deleteSync(recursive: true);
    });
    await helper.excuteSqlAsync('delete from Gallery where id=?', [id]);
  }

  Future<List<GalleryInfo>> listInfo([String? path]) async {
    var userPath = '${config.output}/${path ?? ''}';
    Directory d = Directory(userPath);
    final result = await d
        .list()
        .where((event) => event is Directory)
        .map((event) => GalleryInfo.formDirect(event as Directory, config, api))
        .toList();
    final brokens = <GalleryInfo>[];
    for (var element in result) {
      await element.tryGetGalleryInfo();
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

  @override
  int get hashCode => title.hashCode;
}

enum Relation { Same, DiffChapter, DiffSource, UnRelated }

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
