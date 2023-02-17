import 'dart:io';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:test/test.dart';

void main() async {
  test('image', testSqlHelper);
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
  final List<Language> languages = [Language.japanese, Language.chinese];
  var config = UserContext('.', proxy: '127.0.0.1:8389', languages: languages);
  await config.initData();
  await SqliteHelper(config).updateTagTable();
}

Future<void> testImageSearch() async {
  final List<Language> languages = [Language.japanese, Language.chinese];
  var config = UserContext('.', proxy: '127.0.0.1:8389', languages: languages);
  await config.initData();
  final hitomi = Hitomi.fromPrefenerce(config);
  var ids = await hitomi.findSimilarGalleryBySearch(
      await hitomi.fetchGallery('1333333', usePrefence: false));
  print((await ids.first).item2);
}
