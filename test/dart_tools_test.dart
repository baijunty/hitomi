import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:hitomi/src/multi_paltform.dart';
import 'package:test/test.dart';

int count = 10000;
var config = UserConfig.fromStr(File('config.json').readAsStringSync());
var task = TaskManager(config);
void main() async {
  test('chapter', () async {
    final tags = await task.helper.querySql(
        'select tag from GalleryFile where gid=? order by name', [
      1340882
    ]).then((r) => r
        .map((row) => json.decode(row['tag']) as Map<String, dynamic>)
        .toList());
    var keys = tags
        .map((e) => e.keys)
        .fold(<String>{}, (acc, ks) => acc..addAll(ks)).toList();
    print(keys);
  }, timeout: Timeout(Duration(minutes: 120)));

  test('autoTag', () async {
    var r = await task.down
        .autoTagImages('/home/bai/ssd/manga/(2no.)新婚カノジョ2//01.jpg');
    print(r.first.value.keys.toList());
  });
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
