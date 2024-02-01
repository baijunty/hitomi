import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

var config = UserConfig(r'/home/bai/ssd/photos', proxy: '127.0.0.1:8389');
void main() async {
  test('chapter', () async {
    await Process.run('/home/bai/venv/bin/python3.11', [
      'test/encode.py',
      '/home/bai/ssd/photos/(wakamesan)CHALDEAN SUPPORTER'
    ])
        .then((value) => json.decode(value.stdout))
        .then((value) => print(value[0]));
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
      .then((value) => value.first['thumb'])
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
  return Hitomi.fromPrefenerce(config.output, config.languages,
          proxy: config.proxy)
      .fetchGallery(name, usePrefence: false);
}

Future<Row?> testSqlHelper() async {
  final helper = SqliteHelper('/home/bai/ssd/photos');
  return helper
      .querySql('''SELECT json_key_contains(g.tags,'female') as key,json_value_contains(g.tags,'stockings') as value FROM Gallery g where id=756207''').then(
          (value) => value.firstOrNull);
}

Future<void> testImageDownload() async {
  var token = CancelToken();
  var task = Hitomi.fromPrefenerce(config.output, config.languages,
      proxy: config.proxy);
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
