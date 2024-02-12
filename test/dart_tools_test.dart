import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:hitomi/src/task_manager.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

var config = UserConfig('d:manga',
    proxy: '127.0.0.1:8389', languages: ['chinese', 'japanese'], maxTasks: 5);
void main() async {
  test('chapter', () async {
    // await testThumbHash();
    print(compareHashDistance(-232496494689453701, -2538197667044140165));
  });
}

Future readIdFromFile() async {
  var regex = RegExp(r'title: \((?<artist>.+?)\)');
  await File('fix.log')
      .readAsLines()
      .then((value) => value.expand((e) => regex
          .allMatches(e)
          .map((element) => element.namedGroup('artist'))
          .nonNulls))
      .then((value) => value.toSet())
      .then((value) => print(value.take(20)));
}

Future<void> testThumbHash() async {
  var task = TaskManager(config);

  await task.downLoader.fetchGalleryFromIds([1503421, 1261783, 2240431],
      task.filter, CancelToken(), null).then((value) => print(value.toList()));
  // await task.api
  //     .fetchGallery(1552982, usePrefence: false)
  //     .then((gallery) => task.downLoader.fetchGalleryHashs(gallery))
  //     .then((value) async {
  //   await task.helper.queryImageHashsByLable('artist', 'uno ryoku').then((all) {
  //     print('$value compare ${all[2415675]}');
  //     return task.downLoader
  //         .findSimilerGaller(MapEntry(value.key.id, value.value), all);
  //   }).then((value) => print(value));
  // });
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
