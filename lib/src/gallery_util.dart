import 'dart:typed_data';

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
    return hashes
        .map((e) => all.entries
            .where((element) =>
                element.key != id &&
                element.value.any((hash) => compareHashDistance(hash, e) < 8))
            .fold(
                <int, int>{},
                (previousValue, element) => previousValue
                  ..[element.key] = (previousValue[element.key] ?? 0) + 1)
            .entries
            .where((element) => hashes.length / element.value > 2)
            .map((e) => e.key))
        .fold(<int>{},
            (previousValue, element) => previousValue..addAll(element));
  }

  var head = searchSimiler(gallery.value.sublist(0, 5));
  var middle = searchSimiler(gallery.value
      .sublist(gallery.value.length ~/ 2 - 3, gallery.value.length ~/ 2 + 2));
  var tail = searchSimiler(gallery.value.sublist(gallery.value.length - 5));
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

Future<MapEntry<Gallery, List<int>>> fetchLocalGalleryHash(
    Gallery gallery, SqliteHelper helper) async {
  return helper
      .queryImageHashsById(gallery.id)
      .then((value) => value.fold(<int>[],
          (previousValue, element) => previousValue..add(element['fileHash'])))
      .then((value) => MapEntry<Gallery, List<int>>(gallery, value));
}

Future<MapEntry<Gallery, List<int>>> fetchNetGalleryHash(
    Gallery gallery, Hitomi api,
    [CancelToken? token]) async {
  return [
    ...gallery.files.sublist(0, 5),
    ...gallery.files
        .sublist(gallery.files.length ~/ 2 - 3, gallery.files.length ~/ 2 + 2),
    ...gallery.files.sublist(gallery.files.length - 5)
  ]
      .map((el) => api.getThumbnailUrl(el))
      .asStream()
      .asyncMap((event) => api.downloadImage(
          event, 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}',
          token: token))
      .asyncMap((event) => imageHash(Uint8List.fromList(event)))
      .fold(<int>[], (previous, element) => previous..add(element)).then(
          (value) => MapEntry<Gallery, List<int>>(gallery, value));
}

Future<List<int>> findDuplicateGalleryIds(
    Gallery gallery, SqliteHelper helper, Hitomi api,
    {Logger? logger, bool skipTail = false}) async {
  Map<int, List<int>> allFileHash = gallery.artists != null
      ? await helper.queryImageHashsByLable(
          'artist', gallery.artists!.first.name)
      : gallery.groups != null
          ? await helper.queryImageHashsByLable(
              'groupes', gallery.groups!.first.name)
          : {};
  logger?.d('${gallery.id} hash log length ${allFileHash.length}');
  if (allFileHash.isNotEmpty == true) {
    return fetchLocalGalleryHash(gallery, helper)
        .then((value) async => value.value.isEmpty
            ? await fetchNetGalleryHash(gallery, api)
            : value)
        .then((value) => MapEntry(value.key.id, value.value))
        .then((value) => searchSimilerGaller(value, allFileHash,
            logger: logger, skipTail: skipTail));
  }
  return [];
}
