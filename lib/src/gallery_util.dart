import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';

import '../gallery/gallery.dart';
import 'dhash.dart';

List<int> searchSimilerGaller(
    MapEntry<int, List<int>> gallery, Map<int, List<int>> all,
    {Logger? logger, double threshold = 0.75}) {
  final r = all.entries
      .where((element) =>
          element.key != gallery.key &&
          searchSimiler(gallery.value, element.value) > threshold)
      .map((e) => e.key)
      .toList();
  if (r.isNotEmpty) {
    logger?.d('${gallery.key} found duplication with $r');
  }
  return r;
}

double searchSimiler(List<int> hashes, List<int> other) {
  return hashes
          .where((element) =>
              other.any((hash) => compareHashDistance(hash, element) < 8))
          .length /
      hashes.length;
}

Gallery compareGallerWithOther(
    Gallery gallery, List<Gallery> others, List<String> languages,
    [Logger? logger]) {
  others.sort((g1, g2) => g1.files.length - g2.files.length);
  var max = others.last;
  var diff = gallery.files.length - max.files.length;
  logger?.d('compare $gallery with ${others.map((e) => e).toList()}');
  if (diff < 0 && diff.abs() > 5) {
    return max;
  } else if (diff > 0 && diff.abs() > 5) {
    return gallery;
  }
  var firstLang = languages.indexOf(gallery.language!);
  var min = others.lastWhereOrNull(
      (element) => languages.indexOf(element.language!) < firstLang);
  if (min != null) {
    return min;
  } else {
    return gallery;
  }
}

Future<MapEntry<Gallery, List<int>>> fetchGalleryHash(
    Gallery gallery, SqliteHelper helper, Hitomi api,
    [CancelToken? token, bool fullHash = false, String? outDir]) async {
  return helper
      .queryImageHashsById(gallery.id)
      .then((value) => value.fold(<int>[],
          (previousValue, element) => previousValue..add(element['fileHash'])))
      .then((value) => MapEntry<Gallery, List<int>>(gallery, value))
      .then((value) async {
    if (value.value.length < 18 &&
        outDir != null &&
        gallery.createDir(outDir, createDir: false).existsSync()) {
      final dirPath = gallery.createDir(outDir, createDir: false).path;
      final fs = gallery.files
          .map((element) => File(join(dirPath, element.name)))
          .where((element) => element.existsSync())
          .map((e) => e.readAsBytes());
      return Future.wait(fs.map((e) => e.then((value) => imageHash(value))))
          .then((value) => MapEntry(gallery, value));
    } else {
      return value;
    }
  }).then((value) async => value.value.length < 18
          ? await fetchGalleryHashFromNet(gallery, api, token, fullHash)
          : value);
}

Future<MapEntry<Gallery, List<int>>> fetchGalleryHashFromNet(
    Gallery gallery, Hitomi api,
    [CancelToken? token, bool fullHash = false]) async {
  return (fullHash
          ? gallery.files
          : [
              ...gallery.files.sublist(0, 6),
              ...gallery.files.sublist(
                  gallery.files.length ~/ 2 - 3, gallery.files.length ~/ 2 + 3),
              ...gallery.files.sublist(
                  max(gallery.files.length - 10, gallery.files.length ~/ 3 * 2),
                  max(gallery.files.length - 10,
                          gallery.files.length ~/ 3 * 2) +
                      6)
            ])
      .asStream()
      .slices(5)
      .asyncMap((list) => Future.wait(list.map((event) => api
          .fetchImageData(event,
              refererUrl:
                  'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}',
              token: token,
              id: gallery.id)
          .then((value) => imageHash(Uint8List.fromList(value)))
          .catchError((e) => 0, test: (error) => true))))
      .fold(<int>[], (previous, element) => previous..addAll(element)).then(
          (value) => MapEntry<Gallery, List<int>>(gallery, value));
}

Future<List<int>> findDuplicateGalleryIds(
    Gallery gallery, SqliteHelper helper, Hitomi api,
    {Logger? logger, CancelToken? token}) async {
  Map<int, List<int>> allFileHash = {};
  if (gallery.artists != null) {
    await gallery.artists!
        .asStream()
        .asyncMap(
            (event) => helper.queryImageHashsByLabel('artist', event.name))
        .fold(allFileHash, (previous, element) => previous..addAll(element));
  }
  if (gallery.groups != null) {
    await gallery.groups!
        .asStream()
        .asyncMap(
            (event) => helper.queryImageHashsByLabel('groupes', event.name))
        .fold(allFileHash, (previous, element) => previous..addAll(element));
  }
  if (allFileHash.isNotEmpty == true) {
    // logger?.d('${gallery.id} hash log length ${allFileHash.length}');
    return fetchGalleryHash(gallery, helper, api, token)
        .then((value) => MapEntry(value.key.id, value.value))
        .then(
            (value) => searchSimilerGaller(value, allFileHash, logger: logger))
        .catchError((err) {
      logger?.e(err);
      return <int>[];
    }, test: (error) => true);
  }
  return [];
}
