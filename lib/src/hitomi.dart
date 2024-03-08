import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';
import '../gallery/gallery.dart';
import 'package:crypto/crypto.dart';

abstract class Hitomi {
  Future<bool> downloadImagesById(dynamic id,
      {bool usePrefence = true, CancelToken? token});
  void registerGallery(Future<bool> Function(Message msg));
  Future<bool> downloadImages(Gallery gallery,
      {bool usePrefence = true, CancelToken? token});
  Future<Gallery> fetchGallery(dynamic id,
      {usePrefence = true, CancelToken? token});
  Future<List<int>> search(List<Label> include,
      {List<Label> exclude, int page = 1, CancelToken? token});
  Future<List<int>> fetchIdsByTag(Label tag,
      {Language? language, CancelToken? token});
  Future<List<int>> downloadImage(String url, String refererUrl,
      {CancelToken? token});
  Future<List<List<dynamic>>> fetchTagsFromNet({CancelToken? token});
  String getThumbnailUrl(Image image,
      {ThumbnaiSize size = ThumbnaiSize.smaill, CancelToken? token});
  Stream<Gallery> viewByTag(Label tag, {int page = 1, CancelToken? token});

  Future<T> httpInvoke<T>(String url,
      {Map<String, dynamic>? headers = null,
      CancelToken? token,
      void onProcess(int now, int total)?,
      String method = "get",
      Object? data = null});
  factory Hitomi.fromPrefenerce(String outPut, List<String> languages,
      {String proxy = "DIRECT", Logger? logger = null}) {
    return _HitomiImpl(outPut, languages, proxy: proxy, logger: logger);
  }
}

class _HitomiImpl implements Hitomi {
  static final _regExp = RegExp(r"case\s+(\d+):$");
  static final _codeExp = RegExp(r"b:\s+'(\d+)\/'$");
  static final _valueExp = RegExp(r"var\s+o\s+=\s+(\d);");
  int galleries_index_version = 0;
  int tag_index_version = 0;
  late String code;
  late List<int> codes;
  late int index;
  final List<Future<bool> Function(Message)> _calls = [];
  static final _blank = RegExp(r"\s+");
  static final _titleExp = zhAndJpCodeExp;
  static final _emptyList = const <int>[];
  Dio _dio = Dio();
  final _cache = <Label, List<int>>{};
  final String outPut;
  Timer? _timer;
  Logger? logger;
  final List<String> languages;
  _HitomiImpl(this.outPut, this.languages,
      {String proxy = "DIRECT", Logger? logger = null}) {
    _dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      return HttpClient()
        ..connectionTimeout = Duration(seconds: 60)
        ..idleTimeout = Duration(seconds: 120)
        ..findProxy = (u) => (proxy == "DIRECT") ? 'DIRECT' : 'PROXY $proxy';
    });
    this.logger = logger;
  }

  Future<Gallery> _fetchGalleryJsonById(dynamic id, CancelToken? token) async {
    return httpInvoke<String>('https://ltn.hitomi.la/galleries/$id.js',
            token: token)
        .then((value) => value.indexOf("{") >= 0
            ? value.substring(value.indexOf("{"))
            : value)
        .then((value) {
      final gallery = Gallery.fromJson(value);
      return gallery;
    });
  }

  Future<bool> _loopCallBack(Message msg) async {
    bool b = true;
    for (var element in _calls) {
      b &= await element(msg).catchError((e) {
        logger?.e('_loopCallBack $msg faild $e');
        return true;
      }, test: (error) => true);
    }
    return b;
  }

  @override
  Future<bool> downloadImages(Gallery gallery,
      {usePrefence = true, CancelToken? token}) async {
    await checkInit();
    final id = gallery.id;
    final outPath = outPut;
    Directory dir = gallery.createDir(outPath);
    bool allow = await _loopCallBack(TaskStartMessage(gallery, dir, gallery))
        .catchError((e) => false, test: (error) => true);
    if (!allow) {
      logger?.w('${id} test fiald,skip');
      if (dir.listSync().isEmpty) {
        dir.deleteSync(recursive: true);
      }
      await _loopCallBack(DownLoadFinished(gallery, gallery, dir, false));
      return false;
    }
    logger?.i('down $id to ${dir.path} ${dir.existsSync()}');
    try {
      File(join(dir.path, 'meta.json')).writeAsStringSync(json.encode(gallery));
    } catch (e, stack) {
      logger?.e('write json $e when $stack');
      await _loopCallBack(DownLoadFinished(gallery, gallery, dir, false));
      return false;
    }
    final referer = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
    final missImages = <Image>[];
    for (var i = 0; i < gallery.files.length; i++) {
      Image image = gallery.files[i];
      final out = File(join(dir.path, image.name));
      var b = await _loopCallBack(TaskStartMessage(gallery, out, image));
      if (b) {
        for (var j = 0; j < 3; j++) {
          try {
            final url = getDownLoadUrl(image);
            final time = DateTime.now();
            var data = await httpInvoke<List<int>>(url,
                headers: _buildRequestHeader(url, referer),
                onProcess: ((now, total) => _loopCallBack(
                      DownLoadingMessage(
                          gallery,
                          i,
                          now /
                              1024 /
                              DateTime.now().difference(time).inMilliseconds *
                              1000,
                          total),
                    )),
                token: token);
            if (data.isNotEmpty) {
              await out.writeAsBytes(data, flush: true);
              b = true;
              break;
            }
          } catch (e) {
            logger?.e('down image faild $e');
            await _loopCallBack(IlleagalGallery(gallery.id, e.toString(), i));
            b = false;
          }
        }
        if (!b) {
          missImages.add(image);
        }
        await _loopCallBack(DownLoadFinished(image, gallery, out, b));
      }
    }
    var b = missImages.isEmpty;
    return await _loopCallBack(
            DownLoadFinished(missImages, gallery, dir, missImages.isEmpty)) &&
        b;
  }

  @override
  Future<bool> downloadImagesById(dynamic id,
      {usePrefence = true, CancelToken? token}) async {
    await checkInit();
    final gallery =
        await fetchGallery(id, usePrefence: usePrefence, token: token);
    return await downloadImages(gallery, token: token);
  }

  @override
  Future<List<int>> downloadImage(String url, String refererUrl,
      {CancelToken? token}) async {
    await checkInit();
    final data = await httpInvoke<List<int>>(url,
        headers: _buildRequestHeader(url, refererUrl),
        onProcess: null,
        token: token);
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
  Future<Gallery> fetchGallery(dynamic id,
      {usePrefence = true, CancelToken? token}) async {
    await checkInit();
    var gallery = await _fetchGalleryJsonById(id, token);
    if (usePrefence) {
      gallery = await _findBeseMatch(gallery, token: token);
    }
    return gallery;
  }

  Future<Gallery> _findBeseMatch(Gallery gallery, {CancelToken? token}) async {
    final id = gallery.id;
    final langs = gallery.languages
        ?.where((element) => languages.contains(element.name))
        .toList();
    if (langs?.isNotEmpty == true) {
      final f = languages.firstWhere((element) =>
          langs!.firstWhereOrNull((e) => e.name == element) != null);
      final language = langs!.firstWhere((element) => element.name == f);
      if (id != language.galleryid) {
        logger?.t('use language ${language}');
        var l = await _fetchGalleryJsonById(language.galleryid, token);
        if (await _loopCallBack(TaskStartMessage(l, Directory(''), id))) {
          return l;
        }
      }
    } else if (!languages.any((element) => element == gallery.language)) {
      final found = await _findSimilarGalleryBySearch(gallery, token: token);
      if (found != null) {
        logger?.d('search similar from ${gallery} found  ${found}');
        return found;
      }
      throw 'not found othere target language';
    }
    return gallery;
  }

  Future<Gallery?> _findSimilarGalleryBySearch(Gallery gallery,
      {CancelToken? token}) async {
    List<Label> keys = gallery.title
        .toLowerCase()
        .split(_blank)
        .where((element) => _titleExp.hasMatch(element))
        .where((element) => element.isNotEmpty)
        .map((e) => QueryText(e))
        .take(6)
        .fold(<Label>[], (previousValue, element) {
      previousValue.add(element);
      return previousValue;
    });
    keys.add(TypeLabel(gallery.type));
    keys.addAll(languages.map((e) => Language(name: e)));
    if ((gallery.parodys?.length ?? 0) > 0) {
      keys.addAll(gallery.parodys!);
    }
    if ((gallery.artists?.length ?? 0) > 0) {
      keys.addAll(gallery.artists!);
    }
    logger
        ?.d('search ${gallery.id} ${gallery.dirName} target language by $keys');
    var data = await fetchGalleryHashFromNet(gallery, this, token, true)
        .then((value) => value.value);
    return search(keys, token: token)
        .asStream()
        .expand((element) => element)
        .asyncMap((event) => _fetchGalleryJsonById(event, token))
        .asyncMap((event) => fetchGalleryHashFromNet(event, this, token, true))
        .where((event) => searchSimiler(data, event.value) > 0.75)
        .map((event) => event.key)
        .firstOrNull;
  }

  @override
  Future<List<int>> search(List<Label> include,
      {List<Label> exclude = const [],
      int page = 1,
      usePrefence = true,
      CancelToken? token}) async {
    await checkInit();
    final typeMap = include.groupListsBy((element) => element.runtimeType);
    var includeIds =
        await Stream.fromIterable(typeMap.entries).asyncMap((element) async {
      return await Stream.fromIterable(element.value)
          .asyncMap((e) async => e is Language || e is TypeLabel
              ? await getCacheIdsFromLang(e, token: token)
              : await fetchIdsByTag(e, token: token))
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
              exclude.map((e) => getCacheIdsFromLang(e, token: token)))
          .fold<Set<int>>(includeIds.toSet(), (acc, item) {
        acc.removeAll(item);
        return acc;
      });
      includeIds = filtered.toList();
    }
    logger?.i('search left id ${includeIds.length}');
    return includeIds.reversed.toSet().toList();
  }

  @override
  Future<List<int>> fetchIdsByTag(Label tag,
      {Language? language, CancelToken? token}) {
    if (tag is QueryText) {
      return _fetchQuery(tag.name.toLowerCase(), token);
    } else {
      final useLanguage = language?.name ?? 'all';
      String url;
      if (tag is Language) {
        url = 'https://ltn.hitomi.la/n/${tag.urlEncode()}.nozomi';
      } else {
        url = 'https://ltn.hitomi.la/n/${tag.urlEncode()}-$useLanguage.nozomi';
      }
      return _fetchTagIdsByNet(url, token).then((value) {
        logger?.d('search label $tag found ${value.length}');
        return value;
      });
    }
  }

  Future<List<int>> _fetchQuery(String word, CancelToken? token) async {
    await checkInit();
    final hash =
        sha256.convert(Utf8Encoder().convert(word)).bytes.take(4).toList();
    final url =
        'https://ltn.hitomi.la/galleriesindex/galleries.${galleries_index_version}.index';
    return _fetchNode(url, token: token)
        .then((value) => _netBTreeSearch(url, value, hash, token))
        .then((value) {
      logger?.d('search key $word found ${value.length}');
      return value;
    });
  }

  Future<List<int>> _netBTreeSearch(
      String url, _Node node, List<int> hashKey, CancelToken? token) async {
    var tuple = Tuple2(false, node.keys.length);
    for (var i = 0; i < node.keys.length; i++) {
      var v = hashKey.compareTo(node.keys[i]);
      if (v <= 0) {
        tuple = Tuple2(v == 0, i);
        break;
      }
    }
    if (tuple.item1) {
      return _fetchData(node.datas[tuple.item2], token);
    } else if (node.subnode_addresses.any((element) => element != 0) &&
        node.subnode_addresses[tuple.item2] != 0) {
      return _netBTreeSearch(
          url,
          await _fetchNode(url, start: node.subnode_addresses[tuple.item2]),
          hashKey,
          token);
    }
    return _emptyList;
  }

  Future<List<int>> _fetchData(
      Tuple2<int, int> tuple, CancelToken? token) async {
    await checkInit();
    final url =
        'https://ltn.hitomi.la/galleriesindex/galleries.${galleries_index_version}.data';
    return await httpInvoke<List<int>>(url,
            headers: _buildRequestHeader(url, 'https://hitomi.la/',
                range: tuple.withItem2(tuple.item1 + tuple.item2 - 1)),
            token: token)
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

  Future<List<int>> _fetchTagIdsByNet(String url, CancelToken? token) async {
    return await httpInvoke<List<int>>(url,
            headers: _buildRequestHeader(url, 'https://hitomi.la/'),
            token: token)
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

  Future<_Node> _fetchNode(String url, {int start = 0, CancelToken? token}) {
    return httpInvoke<List<int>>(url,
            headers: _buildRequestHeader(url, 'https://hitomi.la/',
                range: Tuple2(start, start + 463)),
            token: token)
        .then((value) => _Node.parse(value));
  }

  @override
  Stream<Gallery> viewByTag(Label tag,
      {int page = 1, CancelToken? token}) async* {
    var referer = 'https://hitomi.la/${tag.urlEncode()}-all.html';
    if (page > 1) {
      referer += '?page=$page';
    }
    final dataUrl = 'https://ltn.hitomi.la/${tag.urlEncode()}-all.nozomi';
    final ids = await httpInvoke<List<int>>(dataUrl,
            headers: _buildRequestHeader(dataUrl, referer,
                range: Tuple2((page - 1) * 100, page * 100 - 1)),
            token: token)
        .then((value) => mapBytesToInts(value, spilt: 4));
    for (var id in ids) {
      yield await fetchGallery(id, usePrefence: false, token: token);
    }
  }

  Future<List<List<dynamic>>> fetchTagsFromNet({CancelToken? token}) async {
    // var rows = _db.select(
    //     'select intro from Tags where type=? by intro desc', ['author']);
    // Map<String, dynamic> author =
    //     (data['head'] as Map<String, dynamic>)['author'];
    final Map<String, dynamic> data = await httpInvoke<String>(
            'https://github.com/EhTagTranslation/Database/releases/latest/download/db.raw.json',
            token: token)
        .then((value) => json.decode(value));
    if (data['data'] is List<dynamic>) {
      var rows = data['data'] as List<dynamic>;
      var params = rows
          .sublist(1)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => Tuple2(
              e['namespace'] as String, e['data'] as Map<String, dynamic>))
          .fold<List<List<dynamic>>>([], (st, e) {
        final key = ['mixed', 'other', 'cosplayer', 'temp'].contains(e.item1)
            ? 'tag'
            : e.item1.replaceAll('reclass', 'type');
        e.item2.entries.fold<List<List<dynamic>>>(st, (previousValue, element) {
          final name = element.key;
          final value = element.value as Map<String, dynamic>;
          return previousValue
            ..add([
              null,
              key,
              name,
              value['name'],
              value['intro'],
              value['links'],
              null
            ]);
        });
        return st;
      });
      return params;
    }
    return [];
  }

  Future<List<int>> getCacheIdsFromLang(Label label,
      {CancelToken? token}) async {
    await checkInit();
    if (!_cache.containsKey(label)) {
      var result = await fetchIdsByTag(label, token: token);
      logger?.d('fetch label ${label.name} result ${result.length}');
      _cache[label] = result;
    }
    return _cache[label]!;
  }

  Future<T> httpInvoke<T>(String url,
      {Map<String, dynamic>? headers = null,
      CancelToken? token,
      void onProcess(int now, int total)?,
      String method = "get",
      Object? data = null}) async {
    final ua = {
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36 Edg/106.0.1370.47'
    };
    headers?.addAll(ua);
    ResponseType responseType;
    if (T == List<int>) {
      responseType = ResponseType.bytes;
    } else if (T == String) {
      responseType = ResponseType.plain;
    } else {
      responseType = ResponseType.json;
    }
    final useHeader = headers ?? ua;
    return (method == 'get'
            ? _dio.get<T>(url,
                options:
                    Options(headers: useHeader, responseType: responseType),
                cancelToken: token,
                onReceiveProgress: onProcess)
            : _dio.post<T>(url,
                options:
                    Options(headers: useHeader, responseType: responseType),
                data: data,
                cancelToken: token,
                onReceiveProgress: onProcess))
        .then((value) => value.data!)
        .catchError((e) {
      logger?.e("$url throw $e");
      throw e;
    }, test: (e) => true);
  }

  Future<void> initData() async {
    final gg = await httpInvoke<String>('https://ltn.hitomi.la/gg.js')
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
    galleries_index_version = await httpInvoke<String>(
            'https://ltn.hitomi.la/galleriesindex/version?_=${DateTime.now().millisecondsSinceEpoch}')
        .then((value) => int.parse(value));
    tag_index_version = await httpInvoke<String>(
            'https://ltn.hitomi.la/tagindex/version?_=${DateTime.now().millisecondsSinceEpoch}')
        .then((value) => int.parse(value));
  }

  Future<void> checkInit() async {
    if (_timer == null) {
      await initData();
      _timer = Timer.periodic(
          Duration(minutes: 30), (timer) async => await initData());
    }
  }

  String getDownLoadUrl(Image image) {
    return "https://${_getUserInfo(image.hash, 'a')}.hitomi.la/webp/${code}/${_parseLast3HashCode(image.hash)}/${image.hash}.webp";
  }

  String getThumbnailUrl(Image image,
      {ThumbnaiSize size = ThumbnaiSize.smaill, CancelToken? token}) {
    final lastThreeCode = image.hash.substring(image.hash.length - 3);
    var sizeStr;
    switch (size) {
      case ThumbnaiSize.smaill:
        sizeStr = 'webpsmallsmalltn';
        break;
      case ThumbnaiSize.medium:
        sizeStr = 'webpsmalltn';
        break;
      case ThumbnaiSize.big:
        sizeStr = 'webpbigtn';
        break;
    }
    return "https://${_getUserInfo(image.hash, 'tn')}.hitomi.la/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${image.hash}.webp";
  }

  String _getUserInfo(String hash, String postFix) {
    final code = _parseLast3HashCode(hash);
    final userInfo = ['a', 'b'];
    var useIndex = index - (codes.any((element) => element == code) ? 1 : 0);
    return userInfo[useIndex.abs()] + postFix;
  }

  int _parseLast3HashCode(String hash) {
    return int.parse(String.fromCharCode(hash.codeUnitAt(hash.length - 1)),
                radix: 16) <<
            8 |
        int.parse(hash.substring(hash.length - 3, hash.length - 1), radix: 16);
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

  @override
  void registerGallery(Future<bool> Function(Message msg) test) {
    _calls.add(test);
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
