import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/lib.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';

import '../gallery/gallery.dart';

List<int> searchSimilerGaller(
    MapEntry<int, List<int>> gallery, Map<int, List<int>> all,
    {Logger? logger, double threshold = 0.75}) {
  try {
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
  } catch (e, stack) {
    logger?.e(e);
    logger?.e(stack);
    print(stack);
    return [];
  }
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
  if (others.isEmpty) {
    return gallery;
  }
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
    {CancelToken? token,
    bool fullHash = false,
    String? outDir,
    List<int> adHashes = const [],
    Logger? logger}) async {
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
              .map((e) => imageFileHash(e).catchError((err) {
                    logger?.e('${e.path} read bytes and hashimage $err');
                    return api
                        .fetchImageData(
                            gallery.files.firstWhere(
                                (element) => e.path.endsWith(element.name)),
                            refererUrl: 'https://hitomi.la')
                        .fold(<int>[], (acc, l) => acc..addAll(l))
                        .then((value) => e.writeAsBytes(value, flush: true))
                        .then((value) => value.readAsBytes())
                        .then((value) => imageHash(value));
                  }, test: (err) => true));
          return Future.wait(fs).then((value) => MapEntry(gallery, value));
        } else {
          return fetchGalleryHashFromNet(gallery, api, token, fullHash);
        }
      })
      .then((value) => MapEntry(
          value.key,
          value.value
              .whereIndexed((index, hash) =>
                  (value.key.files.length - index) <= 8 ||
                  adHashes.every((ad) => compareHashDistance(hash, ad) > 3))
              .toList()))
      .catchError((err) {
        logger?.e('fetchGalleryHash $err');
        return MapEntry(gallery, <int>[]);
      }, test: (error) => true);
}

Future<MapEntry<Gallery, List<int>>> fetchGalleryHashFromNet(
    Gallery gallery, Hitomi api,
    [CancelToken? token, bool fullHash = false]) async {
  // This function fetches image hashes from the network for a given gallery.
  // It handles cases where the local hashing is not sufficient or desired.
  return (fullHash || gallery.files.length <= 18
          ? gallery.files
          : [
              ...gallery.files.sublist(min(gallery.files.length ~/ 3 - 6, 10),
                  min(gallery.files.length ~/ 3, 16)),
              ...gallery.files.sublist(
                  gallery.files.length ~/ 2 - 3, gallery.files.length ~/ 2 + 3),
              ...gallery.files.sublist(
                  max(gallery.files.length - 10, gallery.files.length ~/ 3 * 2),
                  max(gallery.files.length - 10,
                          gallery.files.length ~/ 3 * 2) +
                      6)
            ])
      .asStream() // Convert the list of files to a stream for processing asynchronously.
      .slices(5) // Split the stream into chunks of 5 files each.
      .asyncMap((list) => Future.wait(list.map((event) => api
          .fetchImageData(event,
              refererUrl:
                  'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}',
              token: token,
              id: gallery.id)
          .fold(<int>[], (acc, l) => acc..addAll(l))
          .then((value) => imageHash(Uint8List.fromList(value)))
          .catchError((e) => 0, test: (error) => true)))) // Fetch image data for each file in the chunk asynchronously.
      .fold(<int>[], (previous, element) => previous..addAll(element)).then(
          (value) => MapEntry<Gallery, List<int>>(gallery, value)); // Combine the results of fetching hashes from the network into a single list and return it as a map entry with the gallery.
}

String titleFixed(String title) {
  final matcher = chapterRex.allMatches(title).toList();
  if (matcher.isNotEmpty) {
    final last = matcher.last;
    final atEnd = title.substring(last.end).isEmpty;
    if (atEnd) {
      return title.substring(0, last.start);
    }
  }
  return title;
}

/// Generates a list of chapter numbers from the given chapter name using regex matching.
List<int> chapter(String name) {
  final matcher = chapterRex.allMatches(name).toList();
  if (matcher.isNotEmpty) {
    final last = matcher.last;
    var start = last.namedGroup('start');
    final digit = start!.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        start.codeUnitAt(0) <= '9'.codeUnitAt(0);
    final atEnd = name.substring(last.end).isEmpty;
    if (digit && atEnd) {
      var chapters = <int>[];
      var end = last.namedGroup('end') ?? start;
      end = end.isNotEmpty ? end : start;
      var from = int.parse(start);
      for (var i = from; i <= int.parse(end); i++) {
        chapters.add(i);
      }
      return chapters;
    } else if (atEnd && start.length == 1) {
      var chapters = <int>[];
      var from = start.codeUnits
          .map((e) => String.fromCharCode(e))
          .map((e) => zhNum.indexOf(e) - 1)
          .first;
      var end = last.namedGroup('end') ?? start;
      end = end.length == 1 ? end : start;
      final to = end.codeUnits
          .map((e) => String.fromCharCode(e))
          .map((e) => zhNum.indexOf(e) - 1)
          .first;
      for (var i = from; i <= to; i++) {
        chapters.add(i);
      }
      return chapters;
    }
  }
  return [];
}

/// Checks if one list of chapter numbers contains another list of chapter numbers.
bool chapterContains(List<int> chapters1, List<int> chapters2) {
  if (chapters1.equals(chapters2)) {
    return false;
  }
  if (chapters1.length < chapters2.length) {
    return false;
  }
  var same = (chapters1.isEmpty ^ chapters2.isEmpty) == false;
  if (same && chapters1.isNotEmpty) {
    chapters2.removeWhere((element) => chapters1.contains(element));
    return chapters2.isEmpty;
  }
  return same;
}

Future<List<int>> findDuplicateGalleryIds(
    {required Gallery gallery,
    required SqliteHelper helper,
    required List<int> fileHashs,
    Logger? logger,
    CancelToken? token,
    bool reserved = false}) async {
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
    var value = MapEntry(gallery.id, fileHashs);
    if (reserved) {
      var map = {value.key: value.value};
      var r = allFileHash.entries
          .where((e) => searchSimilerGaller(e, map, logger: logger).isNotEmpty)
          .fold(<int>[],
              (previousValue, element) => previousValue..add(element.key));
      return r;
    }
    return searchSimilerGaller(value, allFileHash, logger: logger);
  }
  return [];
}
