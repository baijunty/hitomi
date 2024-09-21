import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dir_scanner.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:hitomi/src/multi_paltform.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

var config = UserConfig.fromStr(File('config.json').readAsStringSync())
    .copyWith(logOutput: "");
var task = TaskManager(config);
void main() async {
  test('chapter', () async {
    await task
        .getApiDirect()
        .fetchGallery(554098)
        .then((r) => HitomiDir(r.createDir(config.output), task.down, r))
        .then((r) => r.fixGallery())
        .then((r) => print(r));
  }, timeout: Timeout(Duration(minutes: 120)));

  test('vector', () async {
    await task.helper
        .querySql(
            'select g.id,vector_distance(g1.feature,g.feature) as distance from Gallery g left join Gallery g1 on g1.id=? where g.id!=? and vector_distance(g1.feature,g.feature)<0.1 order by vector_distance(g1.feature,g.feature) limit 20',
            [
              580529,
              580529
            ])
        .then((d) => d
            .map((r) => MapEntry(r['id'] as int, r['distance'] as double))
            .toList())
        .then((l) => print(l));
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

  test('image vit', () async {
    var list = await task.helper
        .queryGalleryByLabel('artist', Artist(artist: 'makoto'))
        .then((d) => d.map((r) => r['id'] as int).toList());
    await sordByVector(2352700, list);
  }, timeout: Timeout(Duration(minutes: 120)));
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
}

Future<bool> sordByVector(int target, List<int> ids) async {
  ids.remove(target);
  var api = task.getApiDirect(local: true);
  print('compare $target list $ids');
  var v1 = await api
      .fetchGallery(target)
      .then((g) => task.down
          .autoTagImages(
              join(g.createDir(config.output).path, g.files.first.name),
              feature: true)
          .then((f) => f.first.data))
      .then((d) => Vector.fromList(d!));
  var vList = await ids
      .asStream()
      .asyncMap((id) => api.fetchGallery(id))
      .asyncMap((g) async {
    var f = await task.down
        .autoTagImages(
            join(g.createDir(config.output).path, g.files.first.name),
            feature: true)
        .then((f) => f.first.data);
    return MapEntry(
        g.id, v1.distanceTo(Vector.fromList(f!), distance: Distance.cosine));
  }).fold(<MapEntry<int, double>>[], (acc, d) => acc..add(d));
  vList.sort((d1, d2) => d1.value.compareTo(d2.value));
  print('sort $vList');
  return true;
}

// This part of the code will be rewritten to use LLaVA to describe images.
Future<String> generateImageDescription(String imagePath) async {
  return task.dio
      .post<Map<String, dynamic>>('http://localhost:11434/api/generate', data: {
        "model": 'llava:13b',
        "prompt": 'what is this?',
        "stream": false,
        'images': [base64.encode(File(imagePath).readAsBytesSync())]
      })
      .then((d) => d.data!)
      .then((r) => r['response']);
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

// Using ID to read Tag from the database for GalleryFile
Future<List<Map<String, dynamic>>> getTagsByGalleryId(int galleryId) async {
  final result = await task.helper.querySql(
    'SELECT tag FROM GalleryFile WHERE gid=?',
    [galleryId],
  );
  return result
      .map((row) => json.decode(row['tag']) as Map<String, dynamic>)
      .toList();
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
