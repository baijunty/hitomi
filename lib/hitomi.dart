import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';
import 'http_tools.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_tools/gallery.dart';

abstract class Hitomi {
  Future<bool> downloadImagesById(String id);
  Future<Gallery> fetchGallery(String id, {usePrefence = true});
  Future<List<int>> search(List<Tag> include,
      {List<Tag> exclude, int page = 1});
  Stream<Gallery> viewByTag(Tag tag, {int page = 1});

  factory Hitomi.fromPrefenerce(UserPrefenerce prefenerce) {
    return _HitomiImpl(prefenerce);
  }

  Future<void> pause();
  Future<void> restart();
}

class UserPrefenerce {
  List<Language> languages;
  String proxy = 'DIRECT';
  String output;
  UserPrefenerce(this.output,
      {this.proxy = 'direct', this.languages = const [Language.chinese]});
}

class _HitomiImpl implements Hitomi {
  final UserPrefenerce prefenerce;
  static final _regExp = RegExp(r"case\s+(\d+):$");
  static final _codeExp = RegExp(r"b:\s+'(\d+)\/'$");
  static final _valueExp = RegExp(r"var\s+o\s+=\s+(\d);");
  static final _blank = RegExp(r"\s+");
  static final _emptyList = const <int>[];
  late String code;
  late List<int> codes;
  late int index;
  Timer? _timer;
  int galleries_index_version = 0;
  _HitomiImpl(this.prefenerce) {}

  Future<Timer> initData() async {
    final gg =
        await http_invke('https://ltn.hitomi.la/gg.js', proxy: prefenerce.proxy)
            .then((ints) {
              return Utf8Decoder().convert(ints);
            })
            .then((value) => LineSplitter.split(value))
            .then((value) => value.toList());
    final codeStr = gg.lastWhere((element) => _codeExp.hasMatch(element));
    code = _codeExp.firstMatch(codeStr)![1]!;
    var valueStr = gg.firstWhere((element) => _valueExp.hasMatch(element));
    index = int.parse(_valueExp.firstMatch(valueStr)![1]!);
    codes = gg
        .where((element) => _regExp.hasMatch(element))
        .map((e) => _regExp.firstMatch(e)![1]!)
        .map((e) => int.parse(e))
        .toList();
    galleries_index_version = await http_invke(
            'https://ltn.hitomi.la/galleriesindex/version?_=${DateTime.now().millisecondsSinceEpoch}',
            proxy: prefenerce.proxy)
        .then((value) => Utf8Decoder().convert(value))
        .then((value) => int.parse(value));
    return Timer.periodic(Duration(minutes: 30), (timer) => initData());
  }

  Future<Gallery> _fetchGalleryJsonById(String id) async {
    _timer = _timer ?? await initData();
    return http_invke('https://ltn.hitomi.la/galleries/$id.js',
            proxy: prefenerce.proxy)
        .then((ints) {
          return Utf8Decoder().convert(ints);
        })
        .then((value) => value.indexOf("{") >= 0
            ? value.substring(value.indexOf("{"))
            : value)
        .then((value) {
          return jsonDecode(value);
        })
        .then((value) => Gallery.fromJson(value));
  }

  @override
  Future<bool> downloadImagesById(String id) async {
    final gallery = await fetchGallery(id);
    var artists = gallery.artists?[0].artist ?? '';
    final outPath = prefenerce.output;
    var dir;
    try {
      final title =
          '${artists.isEmpty ? '' : '($artists)'}${(gallery.japaneseTitle ?? gallery.title)?.replaceAll('/', ' ').replaceAll('.', '。').replaceAll('?', '!').replaceAll('*', '').replaceAll(':', ' ')}';
      dir = Directory("${outPath}/${title}")..createSync();
    } catch (e) {
      print(e);
      dir = Directory("${outPath}/${artists.isEmpty ? '' : '($artists)'}$id")
        ..createSync();
    }
    print(dir);
    File(dir.path + '/' + 'meta.json').writeAsStringSync(json.encode(gallery));
    final List<Files> images = gallery.files;
    final url = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
    while (images.isNotEmpty) {
      Files file = images.removeAt(0);
      final out = File(dir.path + '/' + file.name);
      int count = 0;
      final b = await _checkViallImage(dir, file);
      if (!b) {
        try {
          var data = await downloadImage(file, url);
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

  Future<bool> _checkViallImage(Directory dir, Files image) async {
    final out = File(dir.path + '/' + image.name);
    var b = out.existsSync();
    return b;
  }

  Future<List<int>> downloadImage(Files image, String refererUrl) async {
    final url = _buildDownloadUrl(image);
    final data = await http_invke(url,
        proxy: prefenerce.proxy, headers: _buildRequestHeader(url, refererUrl));
    print(
        '下载${image.name} ${image.height}*${image.width} size ${data.length ~/ 1024}KB');
    return data;
  }

  String _buildDownloadUrl(Files image) {
    return "https://${_getUserInfo(image.hash)}.hitomi.la/webp/${this.code}/${_parseLast3HashCode(image.hash)}/${image.hash}.webp";
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

  String _getUserInfo(String hash) {
    final code = _parseLast3HashCode(hash);
    final userInfo = ['aa', 'ba'];
    var useIndex =
        index - (this.codes.any((element) => element == code) ? 1 : 0);
    return userInfo[useIndex.abs()];
  }

  int _parseLast3HashCode(String hash) {
    return int.parse(String.fromCharCode(hash.codeUnitAt(hash.length - 1)),
                radix: 16) <<
            8 |
        int.parse(hash.substring(hash.length - 3, hash.length - 1), radix: 16);
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
        return _fetchGalleryJsonById(language.galleryid);
      }
    } else if (!prefenerce.languages
        .map((e) => e.name)
        .contains(gallery.language)) {
      final r = await findSimilarGalleryBySearch(gallery);
      if (r == null) {
        throw 'target language not found';
      }
    }
    return gallery;
  }

  Future<Gallery?> findSimilarGalleryBySearch(Gallery gallery) async {
    print('search target language by search');
    List<Tag> keys = gallery.title!
        .split(_blank)
        .map((e) => QueryTag(e))
        .fold(<Tag>[], (previousValue, element) {
      previousValue.add(element);
      return previousValue;
    });
    keys.add(GalleryType.fromName(gallery.type!));
    if ((gallery.parodys?.length ?? 0) > 0) {
      keys.addAll(
          gallery.parodys!.map((s) => Tag(type: 'series', name: s.parody!)));
    }
    if ((gallery.artists?.length ?? 0) > 0) {
      keys.addAll(
          gallery.artists!.map((a) => Tag(type: "artist", name: a.artist!)));
    }
    final ids = await search(keys);
    if (ids.isNotEmpty) {
      final result = await Stream.fromFutures(
              ids.map((e) => _fetchGalleryJsonById(e.toString())))
          .firstWhere((event) =>
              event.title == gallery.title &&
              (event.files.length - gallery.files.length).abs() < 3);
      print(
          'found language at ${result.japaneseTitle ?? result.title} size ${result.files.length}');
      return result;
    }
    return null;
  }

  @override
  Future<List<int>> search(List<Tag> include,
      {List<Tag> exclude = const [], int page = 1}) async {
    _timer = _timer ?? await initData();
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

  Future<List<int>> _fetchIdsByTag(Tag tag, List<Language> language) {
    if (tag is QueryTag) {
      return _fetchQuery(tag.name);
    } else {
      final useLanguage = language.length == 1 ? language.first.name : 'all';
      String url;
      if (tag is Language) {
        url = 'https://ltn.hitomi.la/n/${tag.urlEncode()}.nozomi';
      } else if (tag is SexTag) {
        url = 'https://ltn.hitomi.la/n/tag/${tag}-$useLanguage.nozomi';
      } else {
        url =
            'https://ltn.hitomi.la/n/${tag.type}/${tag.name}-$useLanguage.nozomi';
      }
      return _fetchTagIdsByNet(url);
    }
  }

  Future<List<int>> _fetchQuery(String word) async {
    final hash =
        sha256.convert(Utf8Encoder().convert(word)).bytes.take(4).toList();
    final url =
        'https://ltn.hitomi.la/galleriesindex/galleries.${galleries_index_version}.index';
    return _fetchNode(url).then((value) => _netBTreeSearch(url, value, hash));
  }

  Future<List<int>> _netBTreeSearch(
      String url, Node node, List<int> hashKey) async {
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
        'https://ltn.hitomi.la/galleriesindex/galleries.${galleries_index_version}.data';
    return await http_invke(url,
            proxy: prefenerce.proxy,
            headers: _buildRequestHeader(url, 'https://hitomi.la/',
                range: tuple.withItem2(tuple.item1 + tuple.item2 - 1)))
        .then((value) {
      final view = DataView(value);
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
      final view = DataView(value);
      var number = value.length / 4;
      final data = Set<int>();
      for (var i = 0; i < number; i++) {
        data.add(view.getData(i * 4, 4));
      }
      return data.sorted((a, b) => a.compareTo(b));
    });
  }

  Future<Node> _fetchNode(String url, {int start = 0}) {
    return http_invke(url,
            proxy: prefenerce.proxy,
            headers: _buildRequestHeader(url, 'https://hitomi.la/',
                range: Tuple2(start, start + 463)))
        .then((value) => Node.parse(value));
  }

  @override
  Stream<Gallery> viewByTag(Tag tag, {int page = 1}) async* {
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

  @override
  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> restart() async {}
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

class Node {
  List<List<int>> keys = [];
  List<Tuple2<int, int>> datas = [];
  List<int> subnode_addresses = [];
  Node.parse(List<int> data) {
    final dataView = DataView(data);
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

class DataView {
  List<int> data;
  DataView(this.data);

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

class Tag {
  final String type;
  final String name;
  const Tag({this.type = 'tag', required this.name});

  Tag.fromStr(String input)
      : this.type = input.split(":").first,
        this.name = input.split(":").last;

  @override
  String toString() {
    return "$type:$name";
  }

  String urlEncode() {
    return "$type/${Uri.encodeComponent(name.toLowerCase())}";
  }
}

class Language extends Tag {
  static const all = Language._('all');
  static const japanese = Language._('japanese');
  static const chinese = Language._('chinese');
  static const english = Language._('english');

  const Language._(String name) : super(type: 'language', name: name);
  @override
  String toString() {
    return "$name";
  }

  @override
  String urlEncode() {
    return "index-$name";
  }

  factory Language.fromName(String language) {
    switch (language) {
      case 'japanese':
        return japanese;
      case 'chinese':
        return chinese;
      case 'english':
        return english;
      default:
        return all;
    }
  }
}

class SexTag extends Tag {
  const SexTag._(String sex, String name) : super(type: sex, name: name);

  factory SexTag.fromName(bool male, String name) {
    switch (male) {
      case true:
        return SexTag._('male', name);
      case false:
        return SexTag._('female', name);
      default:
        throw 'wrong type';
    }
  }

  @override
  String urlEncode() {
    return "tag/$type:${Uri.encodeComponent(name.toLowerCase())}";
  }
}

class GalleryType extends Tag {
  static const doujinshi = GalleryType._('doujinshi');
  static const manga = GalleryType._('manga');
  static const artistCG = GalleryType._('artistcg');
  static const gameCG = GalleryType._('gamecg');
  static const anime = GalleryType._('anime');

  const GalleryType._(String name) : super(type: "type", name: name);

  factory GalleryType.fromName(String name) {
    switch (name.toLowerCase()) {
      case "doujinshi":
        return GalleryType.doujinshi;
      case "manga":
        return GalleryType.manga;
      case "artistcg":
        return GalleryType.artistCG;
      case "gamecg":
        return GalleryType.gameCG;
      case "anime":
        return GalleryType.anime;
      default:
        throw 'unknow type';
    }
  }

  @override
  String toString() {
    return name;
  }
}

class QueryTag extends Tag {
  String query;
  QueryTag(this.query) : super(type: '', name: query);
}
