import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:logger/logger.dart';

import '../gallery/gallery.dart';
import 'dhash.dart';

List<int> searchSimilerGaller(
    MapEntry<int, List<int>> gallery, Map<int, List<int>> all,
    {bool skipTail = false, Logger? logger}) {
  int id = gallery.key;
  Set<int> searchSimiler(List<int> hashes) {
    return all.entries
        .where((element) => element.key != id)
        .map((e) => MapEntry(
            e.key,
            e.value.fold(
                0,
                (previousValue, element) =>
                    hashes.any((hash) => compareHashDistance(hash, element) < 8)
                        ? previousValue + 1
                        : previousValue)))
        .where((element) => element.value > hashes.length ~/ 2)
        .map((e) => e.key)
        .toSet();
  }

  var head = searchSimiler(gallery.value.sublist(0, 5));
  var middle = searchSimiler(gallery.value
      .sublist(gallery.value.length ~/ 2 - 3, gallery.value.length ~/ 2 + 2));
  var tail = searchSimiler(gallery.value.sublist(
      max(gallery.value.length - 10, gallery.value.length ~/ 3 * 2),
      max(gallery.value.length - 10, gallery.value.length ~/ 3 * 2) + 5));
  // logger?.d(
  //     '${gallery.key} ${gallery.value.length} has $head $middle $tail ${all.length}');
  var duplication = head
      .where((element) =>
          middle.contains(element) && (skipTail || tail.contains(element)))
      .toSet();
  if (duplication.isNotEmpty) {
    logger?.d('$id skipTail $skipTail duplicate with $duplication');
  }
  return duplication.toList();
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
    [CancelToken? token, bool fullHash = false]) async {
  return helper
      .queryImageHashsById(gallery.id)
      .then((value) => value.fold(<int>[],
          (previousValue, element) => previousValue..add(element['fileHash'])))
      .then((value) => MapEntry<Gallery, List<int>>(gallery, value))
      .then((value) async => value.value.length < 18
          ? await (fullHash
                  ? gallery.files
                  : [
                      ...gallery.files.sublist(0, 6),
                      ...gallery.files.sublist(gallery.files.length ~/ 2 - 3,
                          gallery.files.length ~/ 2 + 3),
                      ...gallery.files.sublist(
                          max(gallery.files.length - 10,
                              gallery.files.length ~/ 3 * 2),
                          max(gallery.files.length - 10,
                                  gallery.files.length ~/ 3 * 2) +
                              6)
                    ])
              .map((el) => api.getThumbnailUrl(el))
              .asStream()
              .slices(5)
              .asyncMap((list) => Future.wait(list.map((event) => api
                  .downloadImage(
                      event, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}',
                      token: token)
                  .then((value) => imageHash(Uint8List.fromList(value)))
                  .catchError((e) => 0, test: (error) => true))))
              .fold(<int>[], (previous, element) => previous..addAll(element)).then((value) => MapEntry<Gallery, List<int>>(gallery, value))
          : value);
}

Future<List<int>> findDuplicateGalleryIds(
    Gallery gallery, SqliteHelper helper, Hitomi api,
    {Logger? logger, bool skipTail = false, CancelToken? token}) async {
  Map<int, List<int>> allFileHash = gallery.artists != null
      ? await helper.queryImageHashsByLabel(
          'artist', gallery.artists!.first.name)
      : gallery.groups != null
          ? await helper.queryImageHashsByLabel(
              'groupes', gallery.groups!.first.name)
          : {};
  if (allFileHash.isNotEmpty == true) {
    // logger?.d('${gallery.id} hash log length ${allFileHash.length}');
    return fetchGalleryHash(gallery, helper, api, token)
        .then((value) => MapEntry(value.key.id, value.value))
        .then((value) => searchSimilerGaller(value, allFileHash,
            logger: logger, skipTail: skipTail))
        .catchError((err) {
      logger?.e(err);
      return <int>[];
    }, test: (error) => true);
  }
  return [];
}
