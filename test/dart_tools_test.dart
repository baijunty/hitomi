import 'dart:io';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:test/test.dart';

void main() async {
  test('image', testImageDownload);
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
  final task = await pool.addNewTask(2473175);
  await Future.delayed(Duration(seconds: 5));
  task.cancel();
  task.start();
  await Future.delayed(Duration(seconds: 15));
}
