import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

var config = UserConfig(r'/home/bai/ssd/photos', proxy: '127.0.0.1:8389');
void main() async {
  test('chapter', () async {
    //-g 'Deko Ga Areba Boko Ga Aru.'
    await testHttpServer();
  });
}

Future<void> testHttpServer() async {
  final c = HttpClient();
  var result = await c
      .postUrl(Uri.parse('http://192.168.1.107:7890/translate'))
      .then((value) {
    value.add("""{"auth":"12345678","tags":[{"tag":"multi-work series"}]}"""
        .codeUnits);
    return value.close();
  }).then((value) => utf8.decodeStream(value));
  print(result);
  result = await c
      .getUrl(Uri.parse('http://192.168.1.107:7890/listTask'))
      .then((value) {
    return value.close();
  }).then((value) => utf8.decodeStream(value));
  print(result);
}
// Future<void> testGalleryInfoDistance() async {
//   var config = UserContext(UserConfig(r'/home/bai/ssd/photos',
//       proxy: '127.0.0.1:8389',
//       languages: ['chinese', 'japanese'],
//       maxTasks: 5));
//   var fix = GalleryManager(config, null);
//   final result = await fix.listInfo().then((value) =>
//       value.fold<Map<GalleryInfo, List<GalleryInfo>>>({}, ((previous, element) {
//         final list = previous[element] ?? [];
//         list.add(element);
//         previous[element] = list;
//         return previous;
//       })));
//   result.entries.where((element) => element.value.length > 1).forEach((entry) {
//     var key = entry.key;
//     var value = entry.value;
//     print('$key and ${value.length}');
//     value.forEach((element) {
//       final reletion = key.relationToOther(element);
//       print('$key and ${element} is $reletion');
//     });
//   });
// }

Future<Gallery> getGalleryInfoFromFile(String name) async {
  var gallery = await getGalleryInfoFromFile(r'2089241');
  var gallery1 = await getGalleryInfoFromFile(r'2087609');
  print(
      "${gallery.id} and ${gallery.chapter()} with ${gallery.nameFixed} and ${gallery.chapterContains(gallery1)} ${gallery == gallery1}");
  var config = UserConfig('/home/bai/ssd/photos',
      proxy: '192.168.1.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5);
  var file = File(config.output + '/$name/meta.json');
  if (file.existsSync()) {
    return Gallery.fromJson(file.readAsStringSync());
  }
  return Hitomi.fromPrefenerce(config).fetchGallery(name, usePrefence: false);
}

Future<void> testImageHash() async {
  var hash1 = await imageHash(
      File(r'/home/bai/ssd/photos/三連休は朝まで生ゆきのん。/01.jpg').readAsBytesSync());
  print(hash1);
}

Future<void> testSqlHelper() async {
  // await config.initData();
  // var f = await config.helper.selectSqlAsync(
  //     r'select translate from Tags where name like ?', ['%yu%']);
  // f.forEach((element) {
  //   print(element.values);
  // });
}

Future<void> testImageSearch() async {
  final hitomi = Hitomi.fromPrefenerce(config);
  var ids = await hitomi.findSimilarGalleryBySearch(
      await hitomi.fetchGallery(1333333, usePrefence: false));
  print((await ids.first).item2);
}

Future<void> testImageDownload() async {
  var token = CancelToken();
  var task = Hitomi.fromPrefenerce(config);
  var gallery = await task.fetchGallery('1467596');
  Directory('${config.output}/${gallery.dirName}').deleteSync(recursive: true);
  task.downloadImages(gallery, token: token);
  await Future.delayed(Duration(seconds: 1));
  token.cancel();
  task.downloadImages(gallery, token: token);
  await Future.delayed(Duration(seconds: 6));
  token.cancel();
  await Future.delayed(Duration(seconds: 20));
}

Future<void> galleryTest() async {
  var helper = SqliteHelper(config.output);
  var gallery = await File(config.output + '/(3104)アイの中に閉じ込めた/meta.json')
      .readAsString()
      .then((value) => Gallery.fromJson(value))
      .then((value) => value.lables());
  print(gallery);
}
