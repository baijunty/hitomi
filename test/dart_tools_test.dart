import 'dart:async';
import 'dart:io';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/gallery_fix.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:test/test.dart';

void main() async {
  test('match', testGalleryInfoDistance);
}

Future<void> testGalleryInfoDistance() async {
  var config = UserContext(UserConfig(r'\\192.168.3.228\ssd\photos',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  var fix = GalleryFix(config);
  final result = await fix
      .listInfo()
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
}

Future<void> testGalleryInfo() async {
  var config = UserContext(UserConfig('.',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  var gallery = GalleryInfo.formDirect(
      Directory(r'\\192.168.3.228\ssd\photos\(takeyuu)鈴谷level110'),
      config.helper);
  await gallery.computeData();
  print(gallery);
}

Future<void> testImageHash(ImageHash hash) async {
  var dis = await distance(File('test1.webp').readAsBytesSync(),
      File('test2.webp').readAsBytesSync(),
      hash: hash);
  print(dis);
  dis = await distance(File('test3.webp').readAsBytesSync(),
      File('test4.webp').readAsBytesSync(),
      hash: hash);
  print(dis);
  dis = await distance(File('test5.webp').readAsBytesSync(),
      File('test6.webp').readAsBytesSync(),
      hash: hash);
  print(dis);
}

Future<void> testSqlHelper() async {
  var config = UserContext(UserConfig('.',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  await config.initData();
  await SqliteHelper(config).updateTagTable();
}

Future<void> testImageSearch() async {
  var config = UserContext(UserConfig('.',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  await config.initData();
  final hitomi = Hitomi.fromPrefenerce(config);
  var ids = await hitomi.findSimilarGalleryBySearch(
      await hitomi.fetchGallery(1333333, usePrefence: false));
  print((await ids.first).item2);
}

Future<void> testImageDownload() async {
  var config = UserConfig('.',
      proxy: '127.0.0.1:8389', languages: ['chinese', 'japanese'], maxTasks: 5);
  var pool = TaskManager(config);
  var task = await pool.addNewTask(45465465489456);
  await Future.delayed(Duration(seconds: 5));
  task.cancel();
  await Future.delayed(Duration(seconds: 1));
  task.start();
  await Future.delayed(Duration(seconds: 5));
  task.cancel();
  task = await pool.addNewTask(2473175);
  await Future.delayed(Duration(seconds: 5));
  task.cancel();
}
