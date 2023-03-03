import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/group.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/parody.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:path/path.dart';

import 'dhash.dart';

class GalleryFix {
  final UserContext context;
  GalleryFix(this.context);
  Future<List<GalleryInfo>> listInfo() async {
    Directory d = Directory(context.outPut);
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
        brokens.add(element);
      }
    }
    brokens.forEach((element) {
      result.remove(element);
    });
    print('dir size ${result.length} broken ${brokens.length}');
    return result;
  }

  // Future<void> delBackUp() async {
  //   Directory('${context.outPut}/backup')
  //       .list()
  //       .where((event) => event is Directory)
  //       .map((event) => GalleryInfo.formDirect(event as Directory, context))
  //       .asyncMap((event) async {
  //         await event.computeHash();
  //         return event;
  //       })
  //       .map((event) => Tuple2(
  //           event,
  //           context.helper.querySql(
  //               'select * from galleryInfo where hash=? limit 1',
  //               [event.hash])?.first))
  //       .forEach((element) {
  //         if (element.item2 != null) {
  //           final name = element.item2!['name'];
  //           bool exists = Directory(name).existsSync();
  //           var metaFile = File(element.item1.directory.path + '/meta.json');
  //           bool metaExists = metaFile.existsSync();
  //           if (exists && !metaExists) {
  //             element.item1.directory.deleteSync(recursive: true);
  //           } else if (!exists || !File(name + '/meta.json').existsSync()) {
  //             var out =
  //                 '${context.outPut}/${basename(element.item1.directory.path)}';
  //             safeRename(element.item1.directory, out);
  //           } else {
  //             print('do ${element.item1.directory.path} with $name self');
  //           }
  //         }
  //       });
  // }

  Future<bool> fix() async {
    Map<GalleryInfo, List<GalleryInfo>> result = await listInfo()
        .then((value) => value.fold<Map<GalleryInfo, List<GalleryInfo>>>({},
                ((previous, element) {
              final list = previous[element] ?? [];
              list.add(element);
              previous[element] = list;
              return previous;
            })))
        .catchError((e) {
      print(e);
      throw e;
    });
    print('result size ${result.length}');
    result.entries.where((element) => element.value.length > 1).forEach((ele) {
      final key = ele.key;
      final value = ele.value;
      value.forEach((element) {
        final reletion = key.relationToOther(element);
        print('$key and ${element} is $reletion');
        switch (reletion) {
          case Relation.Same:
            if (!key.fromHitomi) {
              safeRename(key.directory);
            } else {
              safeRename(element.directory);
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
            if (!key.fromHitomi) {
              safeRename(key.directory);
            } else {
              safeRename(element.directory);
            }
            break;
          case Relation.UnRelated:
            break;
        }
      });
    });
    return true;
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
  static final _serialExp =
      RegExp(r'(?<title>.+?)(\((?<serial>.+?)\))?(\[(?<addition>.+?)\])?$');
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
    print('analynsis ${directory.path}');
    await _tryGetGalleryInfo();
  }

  Future<void> searchFromHitomi(List<Lable> tags) async {
    await computeHash();
    tags.addAll(
        context.languages.fold<List<Lable>>([], (acc, i) => acc..add(i)));
    print('search for  $tags');
    var gallery = this.hash == 0
        ? null
        : await api.search(tags).then((value) async {
            print('result length ${value.length}');
            if (value.length > 50) {
              return null;
            }
            return Stream.fromIterable(value)
                .asyncMap((element) async =>
                    await api.fetchGallery(element, usePrefence: false))
                .asyncMap((value) async {
              int hash1 = await api
                  .downloadImage(value.files.first.getThumbnailUrl(context),
                      'https://hitomi.la${Uri.encodeFull(value.galleryurl!)}')
                  .then((value) => imageHash(Uint8List.fromList(value)))
                  .then((value) => value.foldIndexed<int>(
                      0,
                      (index, acc, element) =>
                          acc |= element ? 1 << (63 - index) : 0));
              final distance = compareHashDistance(hash1, this.hash);
              print(
                  '${value.name} ${value.id} $hash1 and ${this.hash} distance $distance');
              if (distance < 8) {
                return value;
              }
              return null;
            }).firstWhere((element) => element != null, orElse: () => null);
          });
    bool success = gallery != null;
    if (success) {
      final target = '${context.outPut}/${gallery.fixedTitle}';
      await safeRename(directory, target);
      directory = Directory(target);
      final files = gallery.files
          .where((element) =>
              _numberTitle.hasMatch(basenameWithoutExtension(element.name)))
          .map((e) => e.name)
          .toList();
      directory
          .list()
          .where((element) =>
              _numberTitle.hasMatch(basenameWithoutExtension(element.path)))
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
        return _fileNumber.hasMatch(name) &&
            _imageExtensions.contains(extension(name));
      }).toList();
      files.sortBy<num>((element) =>
          int.parse(_fileNumber.firstMatch(element.path)!.namedGroup('num')!));
      img = files.firstOrNull as File?;
    }
    this.hash = await img
            ?.readAsBytes()
            .then((value) => imageHash(value))
            .then((value) => value.foldIndexed<int>(
                0,
                (index, acc, element) =>
                    acc |= element ? 1 << (63 - index) : 0))
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
    helper.excuteSql(
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
      await _ehTitleParse(title);
    } else if (!_numberTitle.hasMatch(title) && _serialExp.hasMatch(title)) {
      var mathces = _serialExp.firstMatch(title)!;
      this.title = mathces.namedGroup('title')!.trim();
      List<Lable> tags = [];
      tags.addAll(title.split(RegExp(r'\s+')).map((e) => QueryText(e)));
      // var serial = mathces.namedGroup('serial');
      await searchFromHitomi(tags);
    } else if (!_numberTitle.hasMatch(title)) {
      return await searchFromHitomi(title
          .split(RegExp(r'\s+'))
          .map((e) => QueryText(e))
          .fold<List<Lable>>([], (acc, i) => acc..add(i)));
    } else {
      this.hash = 0;
      await safeRename(directory);
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
    final mission =
        files.map((e) => File(directory.path + '/' + e)).any((element) {
      return !element.existsSync();
    });
    if (mission) {
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
    if (_serialExp.hasMatch(left)) {
      mathces = _serialExp.firstMatch(left)!;
      this.title = mathces.namedGroup('title')!.trim();
      var serial = mathces.namedGroup('serial');
      if (serial != null && (translate = _tryTransLateFromJp(serial)) != null) {
        tags.add(Parody(parody: translate!));
      }
    }
    tags.addAll(title.split(RegExp(r'\s+')).map((e) => QueryText(e)));
    _chapterParse(title);
    tags.addAll(context.languages);
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
    if (chapter != other.chapter) {
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
