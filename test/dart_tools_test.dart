import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
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
    await testGallerySuggest(554098);
  }, timeout: Timeout(Duration(minutes: 120)));

  test('vector', () async {
    await task.helper
        .querySql(
            'select g.id,vector_distance(g1.feature,g.feature) as distance from Gallery g left join Gallery g1 on g1.id=? where g.id!=? and vector_distance(g1.feature,g.feature)<0.3 order by vector_distance(g1.feature,g.feature) limit 5',
            [1403316, 1403316])
        .then((d) => d.map((r) => '${r['id']}, ${r['distance']}').toList())
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
    // var list = await task.helper
    //     .queryGalleryByLabel('artist', Artist(artist: 'makoto'))
    //     .then((d) => d.map((r) => r['id'] as int).toList());
    await sordByVector(2494905, [2786676]);
  }, timeout: Timeout(Duration(minutes: 120)));

  test('hash compared', () async {
    var v1 = await task.helper
        .queryImageHashsById(844089)
        .then((d) => d.first.fileHash);
    var v2 = await task.helper
        .queryImageHashsById(1280909)
        .then((d) => d.first.fileHash);
    print(compareHashDistance(v1!, v2!));
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
  test('text embedings', () async {
    await textVector('痴漢電車', []);
  }, timeout: Timeout(Duration(minutes: 120)));
}

Future<void> testGallerySuggest(int id) async {
  return task
      .findSugguestGallery(id)
      .then((r) => print(r))
      .catchError((e) => print(e), test: (error) => true);
}

Future<bool> textVector(String target, List<String> strings) async {
  var vectors = await task.dio
      .post<Map<String, dynamic>>('http://127.0.0.1:11434/api/embed',
          data: {
            "model": "nomic-embed-text",
            "input": [target, ...strings]
          },
          options: Options(responseType: ResponseType.json))
      .then((resp) => resp.data!)
      .then((d) => (d['embeddings'] as List<dynamic>)
          .map((dy) => dy as List<dynamic>)
          .map((dl) => mapDynamicList(dl))
          .map((dl) => Vector.fromList(dl))
          .toList());
  var v1 = vectors.removeAt(0);
  var text2vetc = vectors
      .mapIndexed((index, vetc) => MapEntry(
          strings[index], v1.distanceTo(vetc, distance: Distance.cosine)))
      .toList();
  text2vetc.sort((v, v2) => v.value.compareTo(v2.value));
  text2vetc.where((v) => v.value < 0.2).forEachIndexed((index, str) {
    print('$target compre result $str ');
  });
  return true;
}

List<double> mapDynamicList(List<dynamic> list) {
  return list.map((dynamic e) => e as double).toList(growable: false);
}

Future<bool> sordByVector(int target, List<int> ids) async {
  ids.remove(target);
  print('compare $target list $ids');
  var v1 = await generaVectById(target);
  var vList = await ids.asStream().asyncMap((id) async {
    var f = await generaVectById(id);
    return MapEntry(id, v1.distanceTo(f, distance: Distance.cosine));
  }).fold(<MapEntry<int, double>>[], (acc, d) => acc..add(d));
  vList.sort((d1, d2) => d1.value.compareTo(d2.value));
  print('sort $vList');
  return true;
}

Future<Vector> generaVectById(int id) async {
  var api = task.getApiDirect();
  return api.fetchGallery(id).then((g) async {
    var f = File(join(
        g.createDir(config.output, createDir: false).path, g.files.first.name));
    if (f.existsSync()) {
      return f.path;
    } else {
      var tempF = await api
          .fetchImageData(g.files.first, size: ThumbnaiSize.origin)
          .fold(<int>[], (acc, l) => acc..addAll(l))
          .then((d) => File(g.files.first.name).writeAsBytes(d, flush: true))
          .then((f) => f.path);
      return tempF;
    }
  }).then((g) => task.down
      .autoTagImages(g, feature: true)
      .then((f) => Vector.fromList(f.first.data!)));
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
