import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';
import '../gallery/gallery.dart';
import 'package:crypto/crypto.dart';

abstract class Hitomi {
  void registerGallery(Future<bool> Function(Message msg));
  Future<bool> downloadImages(Gallery gallery,
      {bool usePrefence = true, CancelToken? token});
  Future<Gallery> fetchGallery(dynamic id,
      {usePrefence = true, CancelToken? token});
  Future<List<int>> search(List<Label> include,
      {List<Label> exclude, int page = 1, CancelToken? token});
  Future<List<int>> fetchImageData(Image image,
      {String refererUrl,
      CancelToken? token,
      ThumbnaiSize size = ThumbnaiSize.smaill});
  Stream<Gallery> viewByTag(Label tag, {int page = 1, CancelToken? token});
  String buildImageUrl(Image image, {ThumbnaiSize size = ThumbnaiSize.smaill});
  factory Hitomi.fromPrefenerce(TaskManager manager, {bool localDb = false}) {
    final netHitomi = _HitomiImpl(
        manager.config.output, manager.config.languages, manager.dio,
        proxy: manager.config.proxy, logger: manager.logger);
    return localDb ? _LocalHitomiImpl(manager, netHitomi) : netHitomi;
  }
}

class _LocalHitomiImpl implements Hitomi {
  late SqliteHelper _helper;
  final TaskManager _manager;
  final _HitomiImpl _hitomiImpl;
  _LocalHitomiImpl(this._manager, this._hitomiImpl) {
    _helper = _manager.helper;
  }

  @override
  Future<List<int>> fetchImageData(Image image,
      {String refererUrl = '',
      CancelToken? token,
      ThumbnaiSize size = ThumbnaiSize.smaill}) {
    if (size == ThumbnaiSize.origin) {
      return _helper
          .querySql(
              'select path from Gallery g left join GalleryFile gf on g.id=gf.gid where gf.hash=?',
              [
                image.hash
              ])
          .then((value) =>
              join(_manager.config.output, value.first['path'], image.name))
          .then((value) => File(value).readAsBytes() as List<int>)
          .catchError((e) => <int>[], test: (error) => true);
    } else {
      return _helper
          .querySqlByCursor(
              'select thumb from GalleryFile where hash=?', [image.hash])
          .first
          .then((value) => value['thumb'] as List<int>)
          .catchError((e) => <int>[], test: (error) => true);
    }
  }

  @override
  Future<bool> downloadImages(Gallery gallery,
      {bool usePrefence = true, CancelToken? token}) {
    return _hitomiImpl.downloadImages(gallery,
        usePrefence: usePrefence, token: token);
  }

  @override
  Future<Gallery> fetchGallery(id, {usePrefence = true, CancelToken? token}) {
    return _helper
        .queryGalleryById(id)
        .then((value) => value.first['path'])
        .then((value) => readGalleryFromPath(value));
  }

  @override
  void registerGallery(Future<bool> Function(Message msg) Function) {
    _hitomiImpl.registerGallery(Function);
  }

  @override
  Future<List<int>> search(List<Label> include,
      {List<Label> exclude = const [], int page = 1, CancelToken? token}) {
    var group = include.groupListsBy((element) => element is QueryText);
    final sql = StringBuffer('select id from Gallery where ');
    final params = [];
    group[true]?.fold(sql,
        (previousValue, element) => previousValue..write(' title like ? and '));
    group[true]?.fold(params,
        (previousValue, element) => previousValue..add('%${element.name}%'));
    group[false]?.fold(
        sql,
        (previousValue, element) => previousValue
          ..write(' json_value_contains(${element.localSqlType},?,?)=1 and '));
    group[false]?.fold(
        params,
        (previousValue, element) =>
            previousValue..addAll([element.name, element.type]));
    sql.write(' 1=1 limit 20 offset ${(page - 1) * 20}');
    _manager.logger.d('sql is ${sql.toString()} parms = ${params}');
    return _helper
        .querySql(sql.toString(), params)
        .then((value) => value.map((element) => element['id'] as int).toList());
  }

  @override
  Stream<Gallery> viewByTag(Label tag, {int page = 1, CancelToken? token}) {
    return search([tag], page: page, token: token)
        .then((value) => _helper
            .selectSqlMultiResultAsync('select path from Gallery where id=?',
                value.map((e) => [e]).toList())
            .then(
                (value) => value.values.map((e) => e.first['path'] as String)))
        .asStream()
        .expand((element) => element)
        .asyncMap((event) =>
            readGalleryFromPath(join(_manager.config.output, event)));
  }

  @override
  String buildImageUrl(Image image, {ThumbnaiSize size = ThumbnaiSize.smaill}) {
    return _hitomiImpl.buildImageUrl(image, size: size);
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
  final _cache = <Label, List<int>>{};
  final String outPut;
  Timer? _timer;
  Logger? logger;
  final List<String> languages;
  final Dio _dio;
  _HitomiImpl(this.outPut, this.languages, this._dio,
      {String proxy = "DIRECT", Logger? logger = null}) {
    this.logger = logger;
  }

  Future<Gallery> _fetchGalleryJsonById(dynamic id, CancelToken? token) async {
    return _dio
        .httpInvoke<String>('https://ltn.hitomi.la/galleries/$id.js',
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
            final time = DateTime.now();
            var data = await fetchImageData(image,
                refererUrl: referer,
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
                token: token,
                size: ThumbnaiSize.origin);
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
  Future<List<int>> fetchImageData(Image image,
      {String refererUrl = '',
      CancelToken? token,
      void onProcess(int now, int total)?,
      ThumbnaiSize size = ThumbnaiSize.smaill}) async {
    await checkInit();
    final url = buildImageUrl(image, size: size);
    final data = await _dio.httpInvoke<List<int>>(url,
        headers: _buildRequestHeader(url, refererUrl),
        onProcess: onProcess,
        token: token);
    return data;
  }

  @override
  String buildImageUrl(Image image, {ThumbnaiSize size = ThumbnaiSize.smaill}) {
    final lastThreeCode = image.hash.substring(image.hash.length - 3);
    String url;
    var sizeStr;
    switch (size) {
      case ThumbnaiSize.origin:
        {
          url =
              "https://${_getUserInfo(image.hash, 'a')}.hitomi.la/webp/${code}/${_parseLast3HashCode(image.hash)}/${image.hash}.webp";
        }
      case ThumbnaiSize.smaill:
        sizeStr = 'webpsmallsmalltn';
        url =
            "https://${_getUserInfo(image.hash, 'tn')}.hitomi.la/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${image.hash}.webp";
      case ThumbnaiSize.medium:
        sizeStr = 'webpsmalltn';
        url =
            "https://${_getUserInfo(image.hash, 'tn')}.hitomi.la/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${image.hash}.webp";
      case ThumbnaiSize.big:
        sizeStr = 'webpbigtn';
        url =
            "https://${_getUserInfo(image.hash, 'tn')}.hitomi.la/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${image.hash}.webp";
    }
    return url;
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
              : await _fetchIdsByTag(e, token: token))
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

  Future<List<int>> _fetchIdsByTag(Label tag,
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
    return await _dio
        .httpInvoke<List<int>>(url,
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
    return await _dio
        .httpInvoke<List<int>>(url,
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
    return _dio
        .httpInvoke<List<int>>(url,
            headers: _buildRequestHeader(url, 'https://hitomi.la/',
                range: Tuple2(start, start + 463)),
            token: token)
        .then((value) => _Node.parse(value));
  }

  @override
  Stream<Gallery> viewByTag(Label tag, {int page = 1, CancelToken? token}) {
    var referer = 'https://hitomi.la/${tag.urlEncode()}-all.html';
    if (page > 1) {
      referer += '?page=$page';
    }
    final dataUrl = 'https://ltn.hitomi.la/${tag.urlEncode()}-all.nozomi';
    logger?.d('$dataUrl from $referer');
    return _dio
        .httpInvoke<List<int>>(dataUrl,
            headers: _buildRequestHeader(dataUrl, referer,
                range: Tuple2((page - 1) * 100, page * 100 - 1)),
            token: token)
        .then((value) => mapBytesToInts(value, spilt: 4))
        .asStream()
        .expand((element) => element)
        .asyncMap(
            (value) => fetchGallery(value, usePrefence: false, token: token));
  }

  Future<List<int>> getCacheIdsFromLang(Label label,
      {CancelToken? token}) async {
    await checkInit();
    if (!_cache.containsKey(label)) {
      var result = await _fetchIdsByTag(label, token: token);
      logger?.d('fetch label ${label.name} result ${result.length}');
      _cache[label] = result;
    }
    return _cache[label]!;
  }

  Future<void> initData() async {
    final gg = await _dio
        .httpInvoke<String>('https://ltn.hitomi.la/gg.js')
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
    galleries_index_version = await _dio
        .httpInvoke<String>(
            'https://ltn.hitomi.la/galleriesindex/version?_=${DateTime.now().millisecondsSinceEpoch}')
        .then((value) => int.parse(value));
    tag_index_version = await _dio
        .httpInvoke<String>(
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
