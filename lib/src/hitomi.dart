import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';
import '../gallery/gallery.dart';
import 'http_tools.dart';
import 'package:crypto/crypto.dart';

import 'prefenerce.dart';

abstract class Hitomi {
  Future<bool> downloadImagesById(String id);
  Future<Gallery> fetchGallery(String id, {usePrefence = true});
  Future<List<int>> search(List<Lable> include,
      {List<Lable> exclude, int page = 1});
  Future<List<int>> downloadImage(String url, String refererUrl);
  Stream<Gallery> viewByTag(Lable tag, {int page = 1});
  Stream<Tuple2<Gallery, int>> findSimilarGalleryBySearch(Gallery gallery);
  factory Hitomi.fromPrefenerce(UserContext prefenerce) {
    return _HitomiImpl(prefenerce);
  }
}

class _HitomiImpl implements Hitomi {
  final UserContext prefenerce;
  static final _blank = RegExp(r"\s+");
  static final _titleExp =
      RegExp(r'[\u0800-\u4e00|\u4e00-\u9fa5|30A0-30FF|\w]+');
  static final _emptyList = const <int>[];
  _HitomiImpl(this.prefenerce);

  Future<Gallery> _fetchGalleryJsonById(String id) async {
    return http_invke('https://ltn.hitomi.la/galleries/$id.js',
            proxy: prefenerce.proxy)
        .then((ints) {
          return Utf8Decoder().convert(ints);
        })
        .then((value) => value.indexOf("{") >= 0
            ? value.substring(value.indexOf("{"))
            : value)
        .then((value) {
          return Gallery.fromJson(value);
        });
  }

  @override
  Future<bool> downloadImagesById(String id) async {
    final gallery = await fetchGallery(id);
    var artists = gallery.artists?[0].artist ?? '';
    final outPath = prefenerce.outPut.path;
    var dir;
    try {
      final title =
          '${artists.isEmpty ? '' : '($artists)'}${(gallery.japaneseTitle ?? gallery.title).replaceAll('/', ' ').replaceAll('.', '。').replaceAll('?', '!').replaceAll('*', '').replaceAll(':', ' ')}';
      dir = Directory("${outPath}/${title}")..createSync();
    } catch (e) {
      print(e);
      dir = Directory("${outPath}/${artists.isEmpty ? '' : '($artists)'}$id")
        ..createSync();
    }
    print(dir);
    File(dir.path + '/' + 'meta.json').writeAsStringSync(json.encode(gallery));
    final List<Image> images = gallery.files;
    final referer = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
    while (images.isNotEmpty) {
      Image image = images.removeAt(0);
      final out = File(dir.path + '/' + image.name);
      int count = 0;
      final b = await _checkViallImage(dir, image);
      if (!b) {
        try {
          final url = image.getDownLoadUrl(prefenerce);
          var data = await downloadImage(url, referer);
          print(
              '下载${image.name} ${image.height}*${image.width} size ${data.length ~/ 1024}KB');
          await out.writeAsBytes(data, flush: true);
        } catch (e) {
          count++;
          if (count > 3) {
            break;
          }
        }
      }
    }
    print('下载完成');
    return images.isEmpty;
  }

  Future<bool> _checkViallImage(Directory dir, Image image) async {
    final out = File(dir.path + '/' + image.name);
    var b = out.existsSync();
    return b;
  }

  @override
  Future<List<int>> downloadImage(String url, String refererUrl) async {
    final data = await http_invke(url,
        proxy: prefenerce.proxy, headers: _buildRequestHeader(url, refererUrl));
    return data;
  }

  Map<String, dynamic> _buildRequestHeader(String url, String referer,
      {Tuple2<int, int>? range = null,
      void append(Map<String, dynamic> header)?}) {
    Uri uri = Uri.parse(url);
    final headers = {
      'referer': referer,
      'authority': uri.authority,
      'path': uri.path,
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36 Edg/106.0.1370.47'
    };
    if (range != null) {
      headers.putIfAbsent('range', () => 'bytes=${range.item1}-${range.item2}');
    }
    if (append != null) {
      append(headers);
    }
    return headers;
  }

  @override
  Future<Gallery> fetchGallery(String id, {usePrefence = true}) async {
    var gallery = await _fetchGalleryJsonById(id);
    if (usePrefence) {
      gallery = await _findBeseMatch(gallery);
    }
    return gallery;
  }

  Future<Gallery> _findBeseMatch(Gallery gallery) async {
    final id = gallery.id;
    final languages = gallery.languages
        ?.where((element) =>
            prefenerce.languages.map((e) => e.name).contains(element.name))
        .toList();
    if (languages?.isNotEmpty == true) {
      languages!.sort((a, b) => prefenerce.languages
          .indexWhere((l) => l.name == a.name)
          .compareTo(prefenerce.languages.indexWhere((l) => l.name == b.name)));
      final language = languages.first;
      if (id != language.galleryid) {
        print('use language ${language.toJson()}');
        return _fetchGalleryJsonById(language.galleryid!);
      }
    } else if (!prefenerce.languages
        .map((e) => e.name)
        .contains(gallery.language)) {
      final found = await findSimilarGalleryBySearch(gallery).toList();
      if (found.isNotEmpty) {
        found.sort((e1, e2) => e1.item2.compareTo(e2.item2));
        return found.first.item1;
      }
      throw 'not found othere target language';
    }
    return gallery;
  }

  Stream<Tuple2<Gallery, int>> findSimilarGalleryBySearch(
      Gallery gallery) async* {
    List<Lable> keys = gallery.title
        .toLowerCase()
        .split(_blank)
        .where((element) => _titleExp.hasMatch(element))
        .map((e) => QueryText(e))
        .fold(<Lable>[], (previousValue, element) {
      previousValue.add(element);
      return previousValue;
    });
    keys.add(TypeLabel(gallery.type));
    keys.add(prefenerce.languages.first);
    if ((gallery.parodys?.length ?? 0) > 0) {
      keys.addAll(gallery.parodys!);
    }
    if ((gallery.artists?.length ?? 0) > 0) {
      keys.addAll(gallery.artists!);
    }
    print('search target language by $keys');
    final ids = await search(keys);
    final referer = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
    final url = gallery.files.first.getThumbnailUrl(prefenerce);
    var data = await downloadImage(url, referer);
    for (int id in ids) {
      final g1 = await _fetchGalleryJsonById(id.toString());
      final thumbnail = await downloadImage(
          g1.files.first.getThumbnailUrl(prefenerce), referer);
      final huamman_distance = await distance(data, thumbnail);
      print('${g1.title} ${g1.id} distance is $huamman_distance');
      if (huamman_distance <= 4) {
        yield Tuple2(g1, huamman_distance);
      }
    }
  }

  @override
  Future<List<int>> search(List<Lable> include,
      {List<Lable> exclude = const [], int page = 1}) async {
    final languages = include
        .where((element) => element is Language)
        .map((e) => e as Language)
        .toList();
    final tags = include.whereNot((element) => element is Language);
    var includeIds =
        await Stream.fromFutures(tags.map((e) => _fetchIdsByTag(e, languages)))
            .reduce((previous, element) {
      final r = element
          .where((value) =>
              previous.binarySearch(value, (v, v1) => v.compareTo(v1)) >= 0)
          .toList();
      return r;
    });
    if (exclude.isNotEmpty) {
      final filtered =
          await Stream.fromFutures(exclude.map((e) => _fetchIdsByTag(e, [])))
              .fold<Set<int>>(includeIds.toSet(), (acc, item) {
        acc.removeAll(item);
        return acc;
      });
      includeIds = filtered.toList();
    }
    return includeIds.reversed.toList();
  }

  Future<List<int>> _fetchIdsByTag(Lable tag, List<Language> language) {
    if (tag is QueryText) {
      return _fetchQuery(tag.name);
    } else {
      final useLanguage = language.length == 1 ? language.first.name : 'all';
      String url;
      if (tag is Language) {
        url = 'https://ltn.hitomi.la/n/${tag.urlEncode()}.nozomi';
      } else {
        url = 'https://ltn.hitomi.la/n/${tag.urlEncode()}-$useLanguage.nozomi';
      }
      return _fetchTagIdsByNet(url);
    }
  }

  Future<List<int>> _fetchQuery(String word) async {
    final hash =
        sha256.convert(Utf8Encoder().convert(word)).bytes.take(4).toList();
    final url =
        'https://ltn.hitomi.la/galleriesindex/galleries.${prefenerce.galleries_index_version}.index';
    return _fetchNode(url).then((value) => _netBTreeSearch(url, value, hash));
  }

  Future<List<int>> _netBTreeSearch(
      String url, _Node node, List<int> hashKey) async {
    var tuple = Tuple2(false, node.keys.length);
    for (var i = 0; i < node.keys.length; i++) {
      var v = hashKey.compareTo(node.keys[i]);
      if (v <= 0) {
        tuple = Tuple2(v == 0, i);
        break;
      }
    }
    if (tuple.item1) {
      return _fetchData(node.datas[tuple.item2]);
    } else if (node.subnode_addresses.any((element) => element != 0) &&
        node.subnode_addresses[tuple.item2] != 0) {
      return _netBTreeSearch(
          url,
          await _fetchNode(url, start: node.subnode_addresses[tuple.item2]),
          hashKey);
    }
    return _emptyList;
  }

  Future<List<int>> _fetchData(Tuple2<int, int> tuple) async {
    final url =
        'https://ltn.hitomi.la/galleriesindex/galleries.${prefenerce.galleries_index_version}.data';
    return await http_invke(url,
            proxy: prefenerce.proxy,
            headers: _buildRequestHeader(url, 'https://hitomi.la/',
                range: tuple.withItem2(tuple.item1 + tuple.item2 - 1)))
        .then((value) {
      final view = _DataView(value);
      var number = view.getData(0, 4);
      final data = Set<int>();
      for (int i = 1; i <= number; i++) {
        data.add(view.getData(i * 4, 4));
      }
      return data.sorted((a, b) => a.compareTo(b));
    });
  }

  Future<List<int>> _fetchTagIdsByNet(String url) async {
    return await http_invke(url,
            proxy: prefenerce.proxy,
            headers: _buildRequestHeader(url, 'https://hitomi.la/'))
        .then((value) {
      final view = _DataView(value);
      var number = value.length / 4;
      final data = Set<int>();
      for (var i = 0; i < number; i++) {
        data.add(view.getData(i * 4, 4));
      }
      return data.sorted((a, b) => a.compareTo(b));
    });
  }

  Future<_Node> _fetchNode(String url, {int start = 0}) {
    return http_invke(url,
            proxy: prefenerce.proxy,
            headers: _buildRequestHeader(url, 'https://hitomi.la/',
                range: Tuple2(start, start + 463)))
        .then((value) => _Node.parse(value));
  }

  @override
  Stream<Gallery> viewByTag(Lable tag, {int page = 1}) async* {
    var referer = 'https://hitomi.la/${tag.urlEncode()}-all.html';
    if (page > 1) {
      referer += '?page=$page';
    }
    final dataUrl = 'https://ltn.hitomi.la/${tag.urlEncode()}-all.nozomi';
    final ids = await http_invke(dataUrl,
            proxy: prefenerce.proxy,
            headers: _buildRequestHeader(dataUrl, referer,
                range: Tuple2((page - 1) * 100, page * 100 - 1)))
        .then((value) => mapBytesToInts(value, spilt: 4));
    for (var id in ids) {
      yield await fetchGallery(id.toString(), usePrefence: false);
    }
  }
}

extension Comparable on List<int> {
  int compareTo(List<int> other) {
    final len = min(length, other.length);
    for (var i = 0; i < len; i++) {
      if (this[i] > other[i]) {
        return 1;
      } else if (this[i] < other[i]) {
        return -1;
      }
    }
    return 0;
  }
}

class _Node {
  List<List<int>> keys = [];
  List<Tuple2<int, int>> datas = [];
  List<int> subnode_addresses = [];
  _Node.parse(List<int> data) {
    final dataView = _DataView(data);
    var pos = 0;
    var size = dataView.getData(0, 4);
    pos += 4;
    for (var i = 0; i < size; i++) {
      var length = dataView.getData(pos, 4);
      pos += 4;
      keys.add(data.sublist(pos, pos + length));
      pos += length;
    }
    size = dataView.getData(pos, 4);
    pos += 4;
    for (var i = 0; i < size; i++) {
      var start = dataView.getData(pos, 8);
      pos += 8;
      var end = dataView.getData(pos, 4);
      pos += 4;
      datas.add(Tuple2(start, end));
    }
    for (var i = 0; i < 17; i++) {
      var v = dataView.getData(pos, 8);
      pos += 8;
      subnode_addresses.add(v);
    }
  }
  @override
  String toString() {
    return "{keys:$keys,data:$datas,address:$subnode_addresses}";
  }
}

class _DataView {
  List<int> data;
  _DataView(this.data);

  int getData(int start, int length) {
    if (start > data.length || start + length > data.length) {
      throw 'size overflow';
    }
    final subList = data.sublist(start, start + length);
    int r = 0;
    for (var i = 0; i < subList.length; i++) {
      r |= subList[i] << (length - 1 - i) * 8;
    }
    return r;
  }
}
