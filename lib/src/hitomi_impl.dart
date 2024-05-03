import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
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

Hitomi fromPrefenerce(TaskManager _manager, bool localDb) {
  return localDb
      ? _LocalHitomiImpl(_manager, _HitomiImpl(_manager))
      : _HitomiImpl(_manager);
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
      {String refererUrl = 'https://hitomi.la',
      CancelToken? token,
      int id = 0,
      ThumbnaiSize size = ThumbnaiSize.smaill,
      void Function(int now, int total)? onProcess}) {
    if (size == ThumbnaiSize.origin) {
      return _helper
          .querySql(
              'select path from Gallery g left join GalleryFile gf on g.id=gf.gid where g.id=? and gf.hash=?',
              [
                id,
                image.hash
              ])
          .then((value) =>
              join(_manager.config.output, value.first['path'], image.name))
          .then((value) {
            var f = File(value);
            var length = f.lengthSync();
            return f.openRead().fold(<int>[], (previous, element) {
              previous..addAll(element);
              onProcess?.call(previous.length, length);
              return previous;
            });
          })
          .catchError((e) => <int>[], test: (error) => true);
    } else {
      return _helper
          .querySql('select thumb from GalleryFile where gid=? and hash=?',
              [id, image.hash])
          .then((value) => value.first)
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
        .then((value) => Gallery.fromRow(value.first))
        .then((value) {
      return _helper
          .querySql(
              'select hash,width,name,height,fileHash from GalleryFile where gid=? order by name',
              [
                value.id
              ])
          .then((value) => value.fold(
              <Image>[],
              (previousValue, element) => previousValue
                ..add(Image(
                    hash: element['hash'],
                    hasavif: 0,
                    width: element['width'],
                    haswebp: 0,
                    name: element['name'],
                    height: element['height'],
                    fileHash: element['fileHash']))))
          .then((fs) => value..files.addAll(fs));
    }).catchError((e) => _hitomiImpl.fetchGallery(id, usePrefence: usePrefence),
            test: (error) => true);
  }

  @override
  Future<List<Map<String, dynamic>>> translate(List<Label> labels,
      {CancelToken? token}) {
    return _manager
        .translateLabel(labels)
        .then((value) => value.values.toList());
  }

  @override
  void registerCallBack(Future<bool> Function(Message msg) callback) {
    _hitomiImpl.registerCallBack(callback);
  }

  @override
  Future<DataResponse<List<int>>> search(List<Label> include,
      {List<Label> exclude = const [],
      int page = 1,
      CancelToken? token}) async {
    var group = include.groupListsBy((element) => element.runtimeType);
    var excludeGroups = exclude.groupListsBy((element) => element.runtimeType);
    final sql = StringBuffer(
        'select COUNT(*) OVER() AS total_count,id from Gallery where ');
    final params = [];
    group.entries.fold(sql, (previousValue, element) {
      switch (element.key) {
        case QueryText:
          {
            previousValue.write('( ');
            element.value.foldIndexed(sql, (index, previousValue, element) {
              params.add('%${element.name}%');
              if (index != 0) {
                previousValue.write('and ');
              }
              return previousValue..write('title like ? ');
            });
            previousValue.write(') and ');
          }
        case Language:
        case TypeLabel:
          {
            previousValue.write('( ');
            element.value.foldIndexed(sql, (index, previousValue, element) {
              params.addAll([element.name]);
              if (index != 0) {
                previousValue.write('or ');
              }
              return previousValue..write('${element.localSqlType} =? ');
            });
            previousValue.write(') and ');
          }
        default:
          {
            previousValue.write('( ');
            element.value.foldIndexed(sql, (index, previousValue, element) {
              params.addAll([element.name, element.type]);
              if (index != 0) {
                previousValue.write('and ');
              }
              return previousValue
                ..write('json_value_contains(${element.localSqlType},?,?)=1 ');
            });
            previousValue.write(') and ');
          }
      }
      return previousValue;
    });
    excludeGroups.entries.fold(sql, (previousValue, element) {
      switch (element.key) {
        case QueryText:
          {
            previousValue.write('( ');
            element.value.foldIndexed(sql, (index, previousValue, element) {
              params.add('%${element.name}%');
              if (index != 0) {
                previousValue.write('and ');
              }
              return previousValue..write('title not like ? ');
            });
            previousValue.write(') and ');
          }
        case Language:
        case TypeLabel:
          {
            previousValue.write('( ');
            element.value.foldIndexed(sql, (index, previousValue, element) {
              params.addAll([element.name]);
              if (index != 0) {
                previousValue.write('or ');
              }
              return previousValue..write('${element.localSqlType} =? ');
            });
            previousValue.write(') and ');
          }
        default:
          {
            previousValue.write('( ');
            element.value.foldIndexed(sql, (index, previousValue, element) {
              params.addAll([element.name, element.type]);
              if (index != 0) {
                previousValue.write('and ');
              }
              return previousValue
                ..write('json_value_contains(${element.localSqlType},?,?)=0 ');
            });
            previousValue.write(') and ');
          }
      }
      return previousValue;
    });
    sql.write('1=1 limit 25 offset ${(page - 1) * 25}');
    _manager.logger.d('sql is ${sql} parms = ${params}');
    int count = 0;
    return _helper.querySql(sql.toString(), params).then((value) {
      count = value.firstOrNull?['total_count'] ?? 0;
      return value.map((element) => element['id'] as int).toList();
    }).then((value) => DataResponse(value, totalCount: count));
  }

  @override
  Future<DataResponse<List<Gallery>>> viewByTag(Label tag,
      {int page = 1, CancelToken? token, SortEnum? sort}) {
    var sql = '';
    var params = <dynamic>[];
    if (tag is QueryText) {
      sql =
          'select COUNT(*) OVER() AS total_count,g.* from Gallery g where g.title like ? ';
      params.add('%${tag.name}%');
    } else if (tag is TypeLabel) {
      sql =
          'select COUNT(*) OVER() AS total_count,g.* from Gallery g where type =? ';
      params.add(tag.name);
    } else {
      sql =
          'select COUNT(*) OVER() AS total_count,g.* from Gallery g where json_value_contains(${tag.localSqlType},?,?)=1 ';
      params.addAll([tag.name, tag.type]);
    }
    if (sort == SortEnum.Date) {
      sql = '${sql} order by date asc';
    } else if (sort == SortEnum.DateDesc) {
      sql = '${sql} order by date desc';
    }
    sql = '$sql limit 25 offset ${(page - 1) * 25}';
    var count = 0;
    _manager.logger.d('$sql with $params');
    return _helper
        .querySqlByCursor(sql, params)
        .then((value) => value.fold(<Gallery>[], (previous, element) {
              if (count <= 0) {
                count = element['total_count'];
              }
              return previous..add(Gallery.fromRow(element));
            }))
        .then((galleries) => _helper
                .selectSqlMultiResultAsync(
                    'select hash,width,name,height,fileHash from GalleryFile where gid=? order by name',
                    galleries.map((e) => [e.id]).toList())
                .then((value) {
              for (var gallery in galleries) {
                var v = value.entries
                    .firstWhere((element) => element.key[0] == gallery.id);
                var images = v.value.fold(
                    <Image>[],
                    (previousValue, element) => previousValue
                      ..add(Image(
                          hash: element['hash'],
                          hasavif: 0,
                          width: element['width'],
                          haswebp: 0,
                          name: element['name'],
                          height: element['height'],
                          fileHash: element['fileHash'])));
                gallery.files.addAll(images);
              }
              return galleries;
            }))
        .then((data) => DataResponse(data, totalCount: count));
  }

  @override
  void removeCallBack(Future<bool> Function(Message msg) callBack) {
    return _hitomiImpl.removeCallBack(callBack);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSuggestions(String key) {
    return _manager.helper.fetchLabelsFromSql('%$key%');
  }

  @override
  Future<DataResponse<List<Gallery>>> findSimilarGalleryBySearch(
      Gallery gallery,
      {CancelToken? token}) {
    return findDuplicateGalleryIds(gallery, _manager.helper, _hitomiImpl)
        .then((value) => Future.wait(value.map((e) => fetchGallery(e))))
        .then((value) => DataResponse(value, totalCount: value.length));
  }
}

class _HitomiImpl implements Hitomi {
  static final _regExp = RegExp(r"case\s+(\d+):$");
  static final _codeExp = RegExp(r"b:\s+'(\d+)\/'$");
  static final _valueExp = RegExp(r"var\s+o\s+=\s+(\d);");
  static final _totalExp = RegExp(r'\d+-\d+\/(?<totalCount>\d+)');
  int galleries_index_version = 0;
  int tag_index_version = 0;
  late String code;
  late List<int> codes;
  late int index;
  final List<Future<bool> Function(Message)> _calls = [];
  static final _blank = RegExp(r"\s+");
  final _cache = <Label, List<int>>{};
  late String outPut;
  Timer? _timer;
  Logger? logger;
  late List<String> languages;
  late Dio _dio;
  final TaskManager manager;
  _HitomiImpl(this.manager) {
    this.outPut = manager.config.output;
    this.languages = manager.config.languages;
    this.logger = manager.logger;
    this._dio = manager.dio;
    checkInit();
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
      manager.removeAdImages(gallery);
      return gallery;
    });
  }

  Future<bool> _loopCallBack(Message msg) async {
    bool b = true;
    final calls = _calls.toList();
    for (var element in calls) {
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
      File(join(dir.path, 'meta.json'))
          .writeAsStringSync(json.encode(gallery), flush: true);
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
      var b = await _loopCallBack(TaskStartMessage(gallery, out, image)) &&
          (token?.isCancelled ?? false) == false;
      if (b) {
        for (var j = 0; j < 3; j++) {
          try {
            var startTime = DateTime.now().millisecondsSinceEpoch;
            final url =
                buildImageUrl(image, size: ThumbnaiSize.origin, id: gallery.id);
            var writer = out.openWrite();
            int lastTime = startTime;
            await _dio
                .httpInvoke<ResponseBody>(url,
                    headers: buildRequestHeader(url, referer),
                    onProcess: (now, total) async {
                  final realTime = DateTime.now().millisecondsSinceEpoch;
                  if ((realTime - lastTime) / 1000 > 1) {
                    await _loopCallBack(
                      DownLoadingMessage(gallery, i,
                          now / 1024 / (realTime - startTime) * 1000, total),
                    );
                    lastTime = realTime;
                  }
                }, token: token)
                .then((value) => value.stream.fold(
                    writer, (previous, element) => previous..add(element)))
                .then((value) async {
                  await value.flush();
                })
                .whenComplete(() => writer.close());
          } catch (e) {
            logger?.e('down image faild $e');
            await _loopCallBack(IlleagalGallery(gallery.id, e.toString(), i));
            b = false;
          }
        }
        if (!b) {
          out.deleteSync();
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
      {String refererUrl = 'https://hitomi.la',
      CancelToken? token,
      int id = 0,
      ThumbnaiSize size = ThumbnaiSize.smaill,
      void Function(int now, int total)? onProcess}) async {
    await checkInit();
    final url = buildImageUrl(image, size: size, id: id);
    final data = await _dio.httpInvoke<List<int>>(url,
        headers: buildRequestHeader(url, refererUrl),
        onProcess: onProcess,
        token: token);
    return data;
  }

  String buildImageUrl(Image image,
      {ThumbnaiSize size = ThumbnaiSize.smaill, int id = 0}) {
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
        if (l.files.length > 18) {
          return l;
        }
      }
    } else if (!languages.any((element) => element == gallery.language)) {
      final found = await findSimilarGalleryBySearch(gallery, token: token)
          .then((value) => value.data
              .sorted((a, b) => a.files.length - b.files.length)
              .firstOrNull);
      if (found != null) {
        logger?.d('search similar from ${gallery} found  ${found}');
        return found;
      }
      throw 'not found othere target language';
    }
    return gallery;
  }

  @override
  Future<DataResponse<List<Gallery>>> findSimilarGalleryBySearch(
      Gallery gallery,
      {CancelToken? token}) async {
    List<Label> keys = gallery.title
        .toLowerCase()
        .split(_blank)
        .where((element) => zhAndJpCodeExp.hasMatch(element))
        .where((element) => element.isNotEmpty)
        .takeWhile((value) => value != '|')
        .map((e) => QueryText(e))
        .take(5)
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
    if ((gallery.groups?.length ?? 0) > 0) {
      keys.addAll(gallery.groups!);
    }
    logger
        ?.d('search ${gallery.id} ${gallery.dirName} target language by $keys');
    var data = await fetchGalleryHashFromNet(gallery, this, token, false)
        .then((value) => value.value);
    return search(keys, token: token)
        .then((value) {
          assert(value.data.length < 100);
          logger?.d('${value.data}');
          return value;
        })
        .asStream()
        .expand((element) => element.data)
        .asyncMap((event) => _fetchGalleryJsonById(event, token))
        .asyncMap((event) => fetchGalleryHashFromNet(event, this, token, false))
        .where((event) => searchSimiler(data, event.value) > 0.75)
        .map((event) => event.key)
        .fold(<Gallery>[], (previous, element) => previous..add(element))
        .then((value) => DataResponse(value, totalCount: value.length));
  }

  @override
  Future<List<Map<String, dynamic>>> translate(List<Label> labels,
      {CancelToken? token}) {
    return manager
        .translateLabel(labels)
        .then((value) => value.values.toList());
  }

  @override
  Future<DataResponse<List<int>>> search(List<Label> include,
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
          .reduce((previous, e) {
        List<int> r;
        if (element.key == Language || element.key == TypeLabel) {
          r = [...previous, ...e];
          logger?.d(
              '${element.value} merge ${e.length} and ${previous.length} result ${r.length}');
        } else {
          r = previous
              .where((element) =>
                  e.binarySearch(element, (p0, p1) => p1.compareTo(p0)) >= 0)
              .toList();
          logger?.d(
              '${element.value} has ${e.length} pre ${previous.length} result ${r.length}');
        }
        return r;
      }).then((value) =>
              (element.key == Language || element.key == TypeLabel) &&
                      element.value.length > 1
                  ? (value..sort((p0, p1) => p1.compareTo(p0)))
                  : value);
    }).reduce((previous, element) {
      logger?.d('${previous.length} reduce ${element.length}');
      return previous
          .where(
              (e) => element.binarySearch(e, (p0, p1) => p1.compareTo(p0)) >= 0)
          .toList();
    });
    logger?.d('all match ids ${includeIds.length}');
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
    return DataResponse(includeIds, totalCount: includeIds.length);
  }

  Future<List<int>> _fetchIdsByTag(Label tag,
      {Language? language, CancelToken? token}) {
    if (tag is QueryText) {
      return _fetchQuery(
              'https://ltn.hitomi.la/galleriesindex/galleries.${galleries_index_version}.index',
              tag.name.toLowerCase(),
              token)
          .then((value) => _fetchData(value, token));
    } else {
      final useLanguage = language?.name ?? 'all';
      String url;
      if (tag is Language) {
        url = 'https://ltn.hitomi.la/n/${tag.urlEncode()}.nozomi';
      } else {
        url = 'https://ltn.hitomi.la/n/${tag.urlEncode()}-$useLanguage.nozomi';
      }
      return _fetchTagIdsByNet(url, token).then((value) {
        logger?.d('search label $tag found ${value.length} ');
        return value..sort((p0, p1) => p1.compareTo(p0));
      });
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSuggestions(String key,
      {CancelToken? token}) async {
    await checkInit();
    return _fetchQuery(
            'https://ltn.hitomi.la/tagindex/global.$tag_index_version.index',
            key,
            token)
        .then((value) => _fetchTagData(value, token))
        .then((value) => manager.collectedInfo(value))
        .then((value) => value.values.toList());
  }

  Future<List<Label>> _fetchTagData(
      Tuple2<int, int> tuple, CancelToken? token) async {
    await checkInit();
    final url = 'https://ltn.hitomi.la/tagindex/global.$tag_index_version.data';
    return await _dio
        .httpInvoke<List<int>>(url,
            headers: buildRequestHeader(url, 'https://hitomi.la/',
                range: MapEntry(tuple.item1, tuple.item1 + tuple.item2 - 1)),
            token: token)
        .then((value) {
      final view = _DataView(value);
      var number = view.getData(4);
      final sb = StringBuffer();
      List<Label> list = [];
      logger?.d('found $number');
      for (int i = 0; i < number; i++) {
        int len = view.getData(4);
        for (var index = 0; index < len; index++) {
          sb.writeCharCode(view.getData(1));
        }
        String type = sb.toString().replaceAll('/#', '');
        sb.clear();
        len = view.getData(4);
        for (var index = 0; index < len; index++) {
          sb.writeCharCode(view.getData(1));
        }
        String name = sb.toString();
        sb.clear();
        view.getData(4);
        list.add(fromString(type, name));
      }
      return list;
    });
  }

  Future<Tuple2<int, int>> _fetchQuery(
      String url, String word, CancelToken? token) async {
    await checkInit();
    logger?.d('$url with $word');
    final hash =
        sha256.convert(Utf8Encoder().convert(word)).bytes.take(4).toList();
    return _fetchNode(url, token: token)
        .then((value) => _netBTreeSearch(url, value, hash, token));
  }

  Future<Tuple2<int, int>> _netBTreeSearch(
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
      return node.datas[tuple.item2];
    } else if (node.subnode_addresses.any((element) => element != 0) &&
        node.subnode_addresses[tuple.item2] != 0) {
      return _netBTreeSearch(
          url,
          await _fetchNode(url, start: node.subnode_addresses[tuple.item2]),
          hashKey,
          token);
    }
    throw 'not founded';
  }

  Future<List<int>> _fetchData(
      Tuple2<int, int> tuple, CancelToken? token) async {
    await checkInit();
    final url =
        'https://ltn.hitomi.la/galleriesindex/galleries.${galleries_index_version}.data';
    return await _dio
        .httpInvoke<List<int>>(url,
            headers: buildRequestHeader(url, 'https://hitomi.la/',
                range: MapEntry(tuple.item1, tuple.item1 + tuple.item2 - 1)),
            token: token)
        .then((value) {
      final view = _DataView(value);
      var number = view.getData(4);
      final data = Set<int>();
      for (int i = 1; i <= number; i++) {
        data.add(view.getData(4));
      }
      return data.toList();
    });
  }

  Future<List<int>> _fetchTagIdsByNet(String url, CancelToken? token) async {
    return await _dio
        .httpInvoke<List<int>>(url,
            headers: buildRequestHeader(url, 'https://hitomi.la/'),
            token: token)
        .then((value) {
      final view = _DataView(value);
      var number = value.length / 4;
      final data = Set<int>();
      for (var i = 0; i < number; i++) {
        data.add(view.getData(4));
      }
      return data.toList();
    }).catchError((e) {
      logger?.d('fetch tag $url get $e');
      throw e;
    }, test: (error) => true);
  }

  Future<_Node> _fetchNode(String url, {int start = 0, CancelToken? token}) {
    return _dio
        .httpInvoke<List<int>>(url,
            headers: buildRequestHeader(url, 'https://hitomi.la/',
                range: MapEntry(start, start + 463)),
            token: token)
        .then((value) => _Node.parse(value));
  }

  @override
  Future<DataResponse<List<Gallery>>> viewByTag(Label tag,
      {int page = 1, CancelToken? token, SortEnum? sort}) {
    var referer =
        'https://hitomi.la/${tag.urlEncode(sort: sort)}${tag is Language ? '' : '-all'}.html';
    if (page > 1) {
      referer += '?page=$page';
    }
    final dataUrl =
        'https://ltn.hitomi.la/${tag.urlEncode(sort: sort)}${tag is Language ? '' : '-all'}.nozomi';
    logger?.d('$dataUrl from $referer');
    int totalCount = 0;
    return _dio
        .httpInvoke<List<int>>(dataUrl,
            headers: buildRequestHeader(dataUrl, referer,
                range: MapEntry((page - 1) * 100, page * 100 - 1)),
            token: token, responseHead: (header) {
          var range = header[HttpHeaders.contentRangeHeader]?.firstOrNull;
          if (range != null) {
            var match = _totalExp.firstMatch(range);
            var count = match?.namedGroup('totalCount');
            if (count != null) {
              totalCount = int.parse(count) ~/ 4;
            }
          }
        })
        .then((value) => mapBytesToInts(value, spilt: 4))
        .then((value) => Future.wait(value
                .map((e) => fetchGallery(e, usePrefence: false, token: token)))
            .then((value) => DataResponse(value, totalCount: totalCount)));
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
  void registerCallBack(Future<bool> Function(Message msg) test) {
    _calls.add(test);
  }

  @override
  void removeCallBack(Future<bool> Function(Message msg) callBack) {
    _calls.remove(callBack);
  }
}

class _Node {
  List<List<int>> keys = [];
  List<Tuple2<int, int>> datas = [];
  List<int> subnode_addresses = [];
  _Node.parse(List<int> data) {
    final dataView = _DataView(data);
    var size = dataView.getData(4);
    for (var i = 0; i < size; i++) {
      var length = dataView.getData(4);
      keys.add(dataView.getDataList(length));
    }
    size = dataView.getData(4);
    for (var i = 0; i < size; i++) {
      var start = dataView.getData(8);
      var end = dataView.getData(4);
      datas.add(Tuple2(start, end));
    }
    for (var i = 0; i < 17; i++) {
      var v = dataView.getData(8);
      subnode_addresses.add(v);
    }
  }
  @override
  String toString() {
    return "{keys:$keys,data:$datas,address:$subnode_addresses}";
  }
}

class _DataView {
  List<int> _data;
  var _pos = 0;
  _DataView(this._data);

  int getData(int len) {
    var v = _getData(_pos, len);
    _pos += len;
    return v;
  }

  List<int> getDataList(int len) {
    var v = _data.sublist(_pos, _pos + len);
    _pos += len;
    return v;
  }

  int _getData(int start, int length) {
    if (start > _data.length || start + length > _data.length) {
      throw 'size overflow $start + $length >${_data.length}';
    }
    final subList = _data.sublist(start, start + length);
    int r = 0;
    for (var i = 0; i < subList.length; i++) {
      r |= subList[i] << (length - 1 - i) * 8;
    }
    return r;
  }
}

class WebHitomi implements Hitomi {
  final Dio dio;
  final String bashHttp;
  final bool localDb;
  final String auth;
  WebHitomi(this.dio, this.localDb, this.auth, this.bashHttp);

  @override
  Future<bool> downloadImages(Gallery gallery,
      {bool usePrefence = true, CancelToken? token}) async {
    return dio
        .post<String>('$bashHttp/addTask',
            data: json.encode({'auth': auth, 'task': gallery.id.toString()}))
        .then((value) => json.decode(value.data!)['success']);
  }

  @override
  Future<Gallery> fetchGallery(id,
      {usePrefence = true, CancelToken? token}) async {
    return dio
        .post<String>('$bashHttp/proxy/fetchGallery',
            queryParameters: {
              'id': id,
              'usePrefence': usePrefence,
              'local': localDb
            },
            data: json.encode({
              'auth': auth,
            }))
        .then((value) => Gallery.fromJson(value.data!));
  }

  @override
  Future<List<int>> fetchImageData(Image image,
      {String refererUrl = 'https://hitomi.la',
      CancelToken? token,
      int id = 0,
      ThumbnaiSize size = ThumbnaiSize.smaill,
      void Function(int now, int total)? onProcess}) {
    return dio
        .post<List<int>>('$bashHttp/proxy/fetchImageData',
            queryParameters: {
              'hash': image.hash,
              'name': image.name,
              'referer': refererUrl,
              'size': size.name,
              'id': id,
              'local': localDb
            },
            data: json.encode({
              'auth': auth,
            }),
            options: Options(responseType: ResponseType.bytes),
            onReceiveProgress: onProcess)
        .then((value) => value.data!);
  }

  @override
  void registerCallBack(Future<bool> Function(Message msg) callBack) {}

  @override
  void removeCallBack(Future<bool> Function(Message msg) callBack) {}

  @override
  Future<DataResponse<List<int>>> search(List<Label> include,
      {List<Label> exclude = const [], int page = 1, CancelToken? token}) {
    return dio
        .post<String>('$bashHttp/proxy/search',
            data: json.encode({
              'include': include,
              'excludes': exclude,
              'page': page,
              'auth': auth,
              'local': localDb
            }))
        .then((value) => DataResponse.fromStr(value.data!,
            (list) => (list as List<dynamic>).map((e) => e as int).toList()));
  }

  @override
  Future<DataResponse<List<Gallery>>> viewByTag(Label tag,
      {int page = 1, CancelToken? token, SortEnum? sort}) async {
    return dio
        .post<String>('$bashHttp/proxy/viewByTag',
            data: json.encode({
              'tags': [tag],
              'page': page,
              'auth': auth,
              'local': localDb,
              'sort': sort?.name
            }))
        .then((value) => DataResponse<List<Gallery>>.fromStr(
            value.data!,
            (list) => (list as List<dynamic>)
                .map((e) => Gallery.fromJson(e))
                .toList()));
  }

  @override
  Future<List<Map<String, dynamic>>> translate(List<Label> labels,
      {CancelToken? token}) {
    return dio
        .post<String>('${bashHttp}/translate',
            data: json.encode({'auth': auth, 'tags': labels}),
            cancelToken: token)
        .then((value) => json.decode(value.data!) as List<dynamic>)
        .then((value) => value.map((e) => e as Map<String, dynamic>).toList());
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSuggestions(String key) {
    return dio
        .post<String>('$bashHttp/fetchTag/$key',
            data: json.encode({'auth': auth, 'local': localDb}))
        .then((value) {
      return json.decode(value.data!) as List<dynamic>;
    }).then((value) => value
            .map((e) => (e is Map<String, dynamic>)
                ? e
                : json.decode(e.toString()) as Map<String, dynamic>)
            .toList());
  }

  @override
  Future<DataResponse<List<Gallery>>> findSimilarGalleryBySearch(
      Gallery gallery,
      {CancelToken? token}) {
    return dio
        .post<String>('$bashHttp/proxy/findSimilar',
            data: json
                .encode({'gallery': gallery, 'auth': auth, 'local': localDb}))
        .then((value) => DataResponse<List<Gallery>>.fromStr(
            value.data!,
            (list) => (list as List<dynamic>)
                .map((e) => Gallery.fromJson(e))
                .toList()));
  }
}
