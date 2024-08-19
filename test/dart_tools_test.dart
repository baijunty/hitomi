import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/character.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dir_scanner.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:hitomi/src/multi_paltform.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

int count = 10000;
var config = UserConfig.fromStr(File('config.json').readAsStringSync())
    .copyWith(logOutput: "");
var task = TaskManager(config);
void main() async {
  test('chapter', () async {
    final covers = await task.helper
        .queryGalleryByLabel('character', Character(character: 'asuna yuuki'))
        .then((set) async {
      var r = <MapEntry<String, Vector>>[];
      for (var element in set) {
        var g = await readGalleryFromPath(join(config.output, element['path']));
        r.add(await genarateFuture(
            join(g.createDir(config.output).path, g.files.first.name)));
      }
      return r;
    });
    var target = covers.first.value;
    covers.sort((e1, e2) =>
        target.distanceTo(e1.value).compareTo(target.distanceTo(e2.value)));
    covers.forEach(
        (c) => print('${c.key} distance ${target.distanceTo(c.value)}'));
  }, timeout: Timeout(Duration(minutes: 120)));

  test('fix', () async {
    await task.helper
        .queryGalleryById(1798542)
        .then((value) =>
            readGalleryFromPath(join(config.output, value.first['path'])))
        .then((g) =>
            HitomiDir(g.createDir(config.output), task.down, g).fixGallery())
        .then((r) => print(r));
  }, timeout: Timeout(Duration(minutes: 120)));
}

Future<Map<String, dynamic>> genarateTag(String path) {
  return task.down.autoTagImages(path).then((r) => r.first.tags);
}

Future<MapEntry<String, Vector>> genarateFuture(String path) {
  print('generate $path');
  return task.down
      .autoTagImages(path, feature: true)
      .then((r) => MapEntry(r.first.fileName, Vector.fromList(r.first.data!)));
}

Future<Vector> generateVector(String content,
    {String model = 'mxbai-embed-large'}) async {
  print('generate $content');
  var emb = await task.dio
      .post<Map<String, dynamic>>('http://localhost:11434/api/embed',
          data: {"model": model, "input": content})
      .then((d) => d.data!)
      .then((d) => d['embeddings'] as List<dynamic>);
  var data = (emb[0] as List<dynamic>).map((e) => e as double).toList();
  return Vector.fromList(data);
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
