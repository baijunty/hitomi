import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/gallery/tag.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:hitomi/src/multi_paltform.dart';
import 'package:sqlite3/common.dart';
import 'package:test/test.dart';

int count = 10000;
var config = UserConfig('/home/bai/ssd/manga/',
    proxy: '127.0.0.1:8389',
    languages: ['japanese', 'chinese'],
    maxTasks: 5,
    remoteHttp: 'http://127.0.0.1:7890');
var task = TaskManager(config);
void main() async {
  test('chapter', () async {
    var rex = RegExp(r'id: (?<id>\d+)');
    await File('hitomi.log')
        .readAsLines()
        .asStream()
        .expand((element) => element)
        .where((event) => rex.hasMatch(event))
        .map((value) => rex.firstMatch(value)!.namedGroup('id')!)
        .forEach((value) async =>
            task.helper.updateTask(value, value, value, false));
  }, timeout: Timeout(Duration(minutes: 120)));
}

Future<bool> copyFromBack(int page) async {
  print('copy row $page total ${(page + 1) * count}');
  CommonPreparedStatement? stat;
  return await task.helper.databaseOpera(
      'select gft.gid,gft.hash,gft.name,gft.width,gft.height,gft.fileHash,gft.thumb from GalleryFileTemp gft limit $count offset ${page * count}',
      (stmt) {
    stat = stmt;
    return stmt.selectCursor([]);
  }, releaseOnce: false).then((value) async {
    while (value.moveNext()) {
      var element = value.current;
      await task.helper.excuteSqlAsync(
          'replace into GalleryFile(gid,hash,name,width,height,fileHash,thumb) values(?,?,?,?,?,?,?)',
          [
            element['gid'],
            element['hash'],
            element['name'],
            element['width'],
            element['height'],
            element['fileHash'],
            element['thumb']
          ]);
    }
    print('insert complete');
    return true;
  }).catchError((e) {
    print(e);
    return false;
  }, test: (error) => true).whenComplete(() => stat?.dispose());
}

Future readIdFromFile() async {
  var regex = RegExp(r'title: \((?<artist>.+?)\)');
  var value = await File('fix.log')
      .readAsLines()
      .then((value) => value.expand((e) => regex
          .allMatches(e)
          .map((element) => element.namedGroup('artist'))
          .nonNulls))
      .then((value) => value.toSet().toList());
  print(value.length);
  var writer = value.fold(File('artist.txt').openWrite(),
      (previousValue, element) => previousValue..writeln(element));
  await writer.flush();
}

Future<void> testLocalDb(bool local) async {
  final api = createHitomi(task, local, config.remoteHttp);
  await api.search([QueryText('青春'), Artist(artist: 'nagase tooru')]).then(
      (value) => print(value));
  await api.viewByTag(QueryText(''), page: 1).then((value) => print(value));
}

Future<void> testThumbHash(List<int> ids) async {
  await Future.wait(ids
          .map((e) => task.getApiDirect().fetchGallery(e, usePrefence: false)))
      .asStream()
      .expand((element) {
        return element;
      })
      .asyncMap((gallery) =>
          fetchGalleryHash(gallery, task.helper, task.getApiDirect()))
      .map((event) => MapEntry(event.key.id, event.value))
      .fold(<int, List<int>>{}, (previousValue, element) {
        task.logger.i(
            '${element.key} len ${element.value.length} found ${searchSimilerGaller(element, previousValue, logger: task.logger)} with ${previousValue.length}');
        return previousValue..[element.key] = element.value;
      });
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
  return createHitomi(task, false, '').fetchGallery(name, usePrefence: false);
}

Future<void> testImageDownload() async {
  var token = CancelToken();
  var api = createHitomi(task, false, '');
  var gallery = await api.fetchGallery('1467596');
  Directory('${config.output}/${gallery.dirName}').deleteSync(recursive: true);
  api.downloadImages(gallery, token: token);
  await Future.delayed(Duration(seconds: 1));
  token.cancel();
  api.downloadImages(gallery, token: token);
  await Future.delayed(Duration(seconds: 6));
  token.cancel();
  await Future.delayed(Duration(seconds: 20));
}

Future<void> galleryTest() async {
  var gallery = await File(config.output + '/(safi)美玲とみだらなラブイチャします/meta.json')
      .readAsString()
      .then((value) => Gallery.fromJson(value))
      .then((value) => value.labels());
  print(gallery);
}
