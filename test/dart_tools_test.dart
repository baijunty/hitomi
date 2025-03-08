// ignore_for_file: unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dir_scanner.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:hitomi/src/multi_paltform.dart';
import 'package:test/test.dart';

var config = UserConfig.fromStr(File('config.json').readAsStringSync())
    .copyWith(logOutput: "");
var task = TaskManager(config);
void main() async {
  test('chapter', () async {
    await task.getApiDirect().fetchGallery(2739394).then((g) {
      return HitomiDir(g.createDir(task.config.output), task.down, g)
          .fixGallery();
    }).then((r) => print(r));
  }, timeout: Timeout(Duration(minutes: 120)));

  test('vector', () async {
    await task.helper
        .querySql(
            'select g.id,vector_distance(g1.feature,g.feature) as distance from Gallery g left join Gallery g1 on g1.id=? where g.id!=? and vector_distance(g1.feature,g.feature)<0.3 order by vector_distance(g1.feature,g.feature) limit 5',
            [3091377, 3091377])
        .then((d) => d.map((r) => '${r['id']}, ${r['distance']}').toList())
        .then((l) => print(l));
  }, timeout: Timeout(Duration(minutes: 120)));

  test('ad image', () async {
    await task.helper
        .querySql('select * from UserLog where type=?', [1 << 17])
        .then((value) => Map.fromEntries(value.map((element) =>
            MapEntry<int, String>(element['mark'], element['content']))))
        .then((m) {
          var list = m.entries
              .where((s) => compareHashDistance(s.key, 8589934592) < 4);
          print(list.toList());
          return list
              .asStream()
              .asyncMap((e) => task
                  .getApiDirect()
                  .fetchImageData(
                      Image(
                          hash: e.value,
                          hasavif: 0,
                          width: 1024,
                          name: '01.jpg',
                          height: 1024),
                      refererUrl: 'https://hitomi.la/doujinshi/test.html')
                  .fold(<int>[], (l, i) => l..addAll(i)))
              .map((d) => File('adimage.jpg')..writeAsBytesSync(d, flush: true))
              .length;
        });
  }, timeout: Timeout(Duration(minutes: 120)));

  test('ai stable', () async {
    var count =
        await Iterable.generate(100, (i) => i).asStream().asyncMap((v) async {
      print('fuck $v');
      return await task.down.autoTagImages(
          '/mnt/ssd/manga/(2no.)Himitsu no Hokenshitsu/01_000.png',
          feature: true);
    }).fold(0, (acc, v) => acc + v.length);
    print('count ${count}');
  }, timeout: Timeout(Duration(minutes: 120)));

  test('hash compared', () async {
    var hash1 = await task.helper
        .queryImageHashsById(2739394)
        .then((r) => r.fold(<int>[], (l, i) => l..add(i.fileHash!)));
    var hash2 = await task
        .getApiDirect(local: false)
        .fetchGallery(2739396, usePrefence: false)
        .then((g) => fetchGalleryHashFromNet(g, task.down))
        .then((v) => v.value);
    print('$hash1 smiler $hash2 is  ${searchSimiler(hash2, hash1)}');
  }, timeout: Timeout(Duration(minutes: 120)));

  test('hash distance', () async {
    print(compareHashDistance(1126013186873856, 3377813000559104));
  });

  test('image search', () async {
    await task
        .getApiDirect()
        .fetchGallery(2648486)
        .then((value) => task
            .getApiDirect()
            .fetchImageData(value.files.first)
            .fold(<int>[], (acc, d) => acc..addAll(d))
            .then((d) => imageHash(Uint8List.fromList(d)))
            .then((hash) {
              return task.helper.querySql(
                  '''SELECT gid, name,hash_distance(fileHash,?) as distance FROM (SELECT gid, name, fileHash, ROW_NUMBER() OVER (PARTITION BY gid ORDER BY name) AS rn FROM GalleryFile where gid!=?) sub WHERE rn < 3 and hash_distance(fileHash,?) <5 limit 1''',
                  [hash, 2648486, hash]);
            }))
        .then((r) => print(r));
  }, timeout: Timeout(Duration(minutes: 120)));

  Future<void> testGallerySuggest(int id) async {
    return task
        .findSugguestGallery(id)
        .then((r) => print(r))
        .catchError((e) => print(e), test: (error) => true);
  }

  List<double> mapDynamicList(List<dynamic> list) {
    return list.map((dynamic e) => e as double).toList(growable: false);
  }

  Future<void> testLocalDb(bool local) async {
    final api = createHitomi(task, local, config.remoteHttp);
    await api.search([QueryText('青春'), Artist(artist: 'nagase tooru')]).then(
        (value) => print(value));
    await api.viewByTag(QueryText(''), page: 1).then((value) => print(value));
  }

  Future<void> testThumbHash(List<int> ids) async {
    await Future.wait(ids.map(
            (e) => task.getApiDirect().fetchGallery(e, usePrefence: false)))
        .asStream()
        .expand((element) {
          return element;
        })
        .asyncMap((gallery) => fetchGalleryHash(gallery, task.down))
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
    Directory('${config.output}/${gallery.dirName}')
        .deleteSync(recursive: true);
    api.downloadImages(gallery, token: token);
    await Future.delayed(Duration(seconds: 1));
    token.cancel();
    api.downloadImages(gallery, token: token);
    await Future.delayed(Duration(seconds: 6));
    token.cancel();
    await Future.delayed(Duration(seconds: 20));
  }
}
