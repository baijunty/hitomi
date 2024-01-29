import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:test/test.dart';

var config = UserConfig(r'/home/bai/ssd/photos', proxy: '127.0.0.1:8389');
void main() async {
  test('chapter', () async {
    await resizeThumbImage(
            File(r'/home/bai/ssd/photos/(kikurage)恋姦1-9/001.jpg')
                .readAsBytesSync(),
            256,
            60)
        .then((value) => print(value?.length));
  });
}

Future<int> testStream(int input) async {
  print('$input sleep ${6 - input}');
  var time = DateTime.now();
  await Future.delayed(Duration(seconds: 6 - input), () => input);
  return DateTime.now().difference(time).inSeconds;
}

Future<void> testSqliteImage() async {
  final helper = SqliteHelper('/home/bai/ssd/photos');
  await helper
      .querySql(
          'select thumb from GalleryFile where gid=2273946 order by name limit 1')
      .then((value) => value?.first['thumb'])
      .then((value) => File('test.jpg').writeAsBytes(value, flush: true));
}

Future<void> testHttpServer() async {
  final c = HttpClient();
  var result = await c
      .postUrl(Uri.parse('http://127.0.0.1:7890/translate'))
      .then((value) {
    value.add("""{"auth":"12345678","tags":[{"tag":"multi-work series"}]}"""
        .codeUnits);
    return value.close();
  }).then((value) => utf8.decodeStream(value));
  print(result);
  // result = await c
  //     .getUrl(Uri.parse('http://192.168.1.107:7890/listTask'))
  //     .then((value) {
  //   return value.close();
  // }).then((value) => utf8.decodeStream(value));
  // print(result);
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
  var gallery = await File(config.output + '/(safi)美玲とみだらなラブイチャします/meta.json')
      .readAsString()
      .then((value) => Gallery.fromJson(value))
      .then((value) => value.lables());
  print(gallery);
}
