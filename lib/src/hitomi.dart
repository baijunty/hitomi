import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';
import '../gallery/gallery.dart';
import 'http_tools.dart';
import 'package:crypto/crypto.dart';

abstract class Hitomi {
  Future<bool> downloadImagesById(dynamic id,
      {void onProcess(Message msg)?, bool usePrefence = true});
  Future<Gallery> fetchGallery(dynamic id, {usePrefence = true});
  Future<List<int>> search(List<Lable> include,
      {List<Lable> exclude, int page = 1});
  Future<List<int>> fetchIdsByTag(Lable tag, [Language? language]);
  Future<List<int>> downloadImage(String url, String refererUrl,
      {void onProcess(int now, int total)?});
  Stream<Gallery> viewByTag(Lable tag, {int page = 1});
  Stream<Tuple2<Gallery, int>> findSimilarGalleryBySearch(Gallery gallery);
  factory Hitomi.fromPrefenerce(UserContext prefenerce) {
    return _HitomiImpl(prefenerce);
  }
}

class Message<T> {
  final T id;
  bool success;
  Message({required this.id, required this.success});

  @override
  String toString() {
    return 'Message{$id,$success}';
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this)) return true;
    if (other is! Message) return false;
    return other.id == id;
  }
}

class DownLoadMessage extends Message<int> {
  int current;
  int maxPage;
  double speed;
  int length;
  String title;
  DownLoadMessage(id, success, this.title, this.current, this.maxPage,
      this.speed, this.length)
      : super(id: id, success: success);
  @override
  String toString() {
    return 'DownLoadMessage{$id,$title,$current $maxPage,$speed,$length,$success}';
  }
}

class _HitomiImpl implements Hitomi {
  final UserContext prefenerce;
  static final _blank = RegExp(r"\s+");
  static final _titleExp = zhAndJpCodeExp;
  static final _emptyList = const <int>[];
  _HitomiImpl(this.prefenerce);

  Future<Gallery> _fetchGalleryJsonById(dynamic id) async {
    return http_invke('https://ltn.hitomi.la/galleries/$id.js',
            proxy: prefenerce.proxy)
        .then((ints) {
          return Utf8Decoder().convert(ints);
        })
        .then((value) => value.indexOf("{") >= 0
            ? value.substring(value.indexOf("{"))
            : value)
        .then((value) {
          final gallery = Gallery.fromJson(value);
          // gallery.translateLable(prefenerce.helper);
          return gallery;
        });
  }

  @override
  Future<bool> downloadImagesById(dynamic id,
      {void onProcess(Message msg)?, usePrefence = true}) async {
    final gallery = await fetchGallery(id, usePrefence: usePrefence);
    await prefenerce.helper.updateTask(gallery, false);
    var artists = gallery.artists;
    final outPath = prefenerce.outPut;
    final title = gallery.fixedTitle;
    var b = gallery.tags?.any((element) =>
            prefenerce.exclude.map((e) => e.name).contains(element.tag)) ??
        false;
    if (b && usePrefence) {
      print('${id} include exclude key,continue?(Y/n)');
      var confirm = stdin.readLineSync();
      if (confirm?.toLowerCase().toLowerCase() != 'y') {
        return false;
      }
    }
    Directory dir;
    try {
      dir = Directory("${outPath}/${title}")..createSync();
    } catch (e) {
      print(e);
      dir = Directory(
          "${outPath}/${artists?.isNotEmpty ?? false ? '' : '(${artists!.first.name})'}$id")
        ..createSync();
    }
    print('down $id to ${dir.path}');
    File(dir.path + '/' + 'meta.json').writeAsString(json.encode(gallery));
    final referer = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
    final result = <bool>[];
    for (var i = 0; i < gallery.files.length; i++) {
      Image image = gallery.files[i];
      final out = File(dir.path + '/' + image.name);
      var b = await _checkViallImage(dir, image);
      if (!b) {
        for (var j = 0; j < 3; j++) {
          try {
            final url = image.getDownLoadUrl(prefenerce);
            final time = DateTime.now();
            var data = await downloadImage(url, referer,
                onProcess: onProcess == null
                    ? null
                    : (now, total) => onProcess(DownLoadMessage(
                        id,
                        true,
                        title,
                        i + 1,
                        gallery.files.length,
                        now /
                            1024 /
                            DateTime.now().difference(time).inMilliseconds *
                            1000,
                        total)));
            await out.writeAsBytes(data, flush: true);
            b = true;
            break;
          } catch (e) {
            print(e);
          }
        }
      }
      result.add(b);
    }
    b = !result.any((element) => !element);
    print('下载$id完成$b');
    if (b) {
      await gallery.translateLable(prefenerce.helper);
      await prefenerce.helper.removeTask(gallery.id);
    } else {
      await prefenerce.helper.updateTask(gallery, true);
    }
    return b;
  }

  Future<bool> _checkViallImage(Directory dir, Image image) async {
    final out = File(dir.path + '/' + image.name);
    var b = out.existsSync();
    return b;
  }

  @override
  Future<List<int>> downloadImage(String url, String refererUrl,
      {void onProcess(int now, int total)?}) async {
    final data = await http_invke(url,
        proxy: prefenerce.proxy,
        headers: _buildRequestHeader(url, refererUrl),
        onProcess: onProcess);
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
  Future<Gallery> fetchGallery(dynamic id, {usePrefence = true}) async {
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
        return _fetchGalleryJsonById(language.galleryid!.toInt());
      }
    } else if (!prefenerce.languages
        .map((e) => e.name)
        .contains(gallery.language)) {
      final found = await findSimilarGalleryBySearch(gallery).toList();
      if (found.isNotEmpty) {
        found.sort((e1, e2) => e1.item2.compareTo(e2.item2));
        print(
            'use  ${found.first.item1.fixedTitle} id ${found.first.item1.id} distance ${found.first.item2}');
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
        .where((element) => element.isNotEmpty)
        .map((e) => QueryText(e))
        .take(6)
        .fold(<Lable>[], (previousValue, element) {
      previousValue.add(element);
      return previousValue;
    });
    keys.add(TypeLabel(gallery.type));
    keys.addAll(prefenerce.languages);
    if ((gallery.parodys?.length ?? 0) > 0) {
      keys.addAll(gallery.parodys!);
    }
    if ((gallery.artists?.length ?? 0) > 0) {
      keys.addAll(gallery.artists!);
    }
    print('search target language by $keys');
    final ids = await search(keys, exclude: prefenerce.exclude);
    final referer = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
    final url = gallery.files.first.getThumbnailUrl(prefenerce);
    var data = await downloadImage(url, referer);
    for (int id in ids) {
      final g1 = await _fetchGalleryJsonById(id);
      final thumbnail = await downloadImage(
          g1.files.first.getThumbnailUrl(prefenerce), referer);
      final hamming_distance = await distance(data, thumbnail);
      final langIndex = prefenerce.languages
          .indexWhere((element) => element.name == g1.language);
      if (hamming_distance <= 16 && langIndex >= 0) {
        yield Tuple2(g1, hamming_distance + langIndex);
      }
    }
  }

  @override
  Future<List<int>> search(List<Lable> include,
      {List<Lable> exclude = const [],
      int page = 1,
      usePrefence = true}) async {
    final typeMap = include.groupListsBy((element) => element.runtimeType);
    var includeIds =
        await Stream.fromIterable(typeMap.entries).asyncMap((element) async {
      return await Stream.fromIterable(element.value)
          .asyncMap((e) async => e is Language
              ? await prefenerce.getCacheIdsFromLang(e)
              : await fetchIdsByTag(e))
          .fold<Set<int>>(
              {},
              (previous, e) => element.key == QueryText
                  ? previous
                      .where((element) =>
                          e.binarySearch(
                              element, (p0, p1) => p0.compareTo(p1)) >=
                          0)
                      .toSet()
                  : previous
                ..addAll(e)).then(
              (value) => value.sorted((a, b) => a.compareTo(b)));
    }).reduce((previous, element) {
      return previous
          .where(
              (e) => element.binarySearch(e, (p0, p1) => p0.compareTo(p1)) >= 0)
          .toList();
    });
    if (exclude.isNotEmpty && includeIds.isNotEmpty) {
      final filtered = await Stream.fromFutures(
              exclude.map((e) => prefenerce.getCacheIdsFromLang(e)))
          .fold<Set<int>>(includeIds.toSet(), (acc, item) {
        acc.removeAll(item);
        return acc;
      });
      includeIds = filtered.toList();
    }
    return includeIds.reversed.toList();
  }

  @override
  Future<List<int>> fetchIdsByTag(Lable tag, [Language? language]) {
    if (tag is QueryText) {
      return _fetchQuery(tag.name.toLowerCase());
    } else {
      final useLanguage = language?.name ?? 'all';
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
      yield await fetchGallery(id, usePrefence: false);
    }
  }
}

List<int> mapBytesToInts(List<int> resp, {int spilt = 4}) {
  if (resp.length % spilt != 0) {
    throw 'not $spilt times';
  }
  final result = <int>[];
  for (var i = 0; i < resp.length / spilt; i++) {
    var subList = resp.sublist(i * spilt, i * spilt + spilt);
    int r = 0;
    for (var i = 0; i < subList.length; i++) {
      r |= subList[i] << (spilt - 1 - i) * 8;
    }
    result.add(r);
  }
  return result;
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
      throw 'size overflow $start + $length >${data.length}';
    }
    final subList = data.sublist(start, start + length);
    int r = 0;
    for (var i = 0; i < subList.length; i++) {
      r |= subList[i] << (length - 1 - i) * 8;
    }
    return r;
  }
}
