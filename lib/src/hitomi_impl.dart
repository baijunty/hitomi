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
  Stream<List<int>> fetchImageData(Image image,
      {String refererUrl = 'https://hitomi.la',
      CancelToken? token,
      int id = 0,
      bool translate = false,
      String lang = 'ja',
      ThumbnaiSize size = ThumbnaiSize.smaill,
      void Function(int now, int total)? onProcess}) {
    var origin = _helper
        .querySql('select g.path from Gallery g where g.id=?', [id]).then(
            (value) =>
                join(_manager.config.output, value.first['path'], image.name));
    final stream = StreamController<List<int>>();
    if (size == ThumbnaiSize.origin) {
      origin.then((value) async {
        var f = File(value);
        var length = f.lengthSync();
        var count = 0;
        if (translate) {
          await _manager.dio
              .post<ResponseBody>('${_manager.config.aiTagPath}/evaluate',
                  data: FormData.fromMap({
                    'file': MultipartFile.fromStream(() => f.openRead(), length,
                        filename: image.name),
                    'lang': lang,
                    'process': 'translate'
                  }),
                  options: Options(responseType: ResponseType.stream),
                  onReceiveProgress: onProcess)
              .then((resp) => stream.addStream(resp.data!.stream));
        } else {
          await f.openRead().fold(stream, (previous, element) {
            count += element.length;
            onProcess?.call(count, length);
            previous.add(element);
            return previous;
          });
        }
        stream.close();
      }).catchError((e) {
        stream.addError(e);
        stream.close();
      }, test: (error) => true);
    } else if (_manager.config.aiTagPath.isNotEmpty) {
      origin
          .then((value) => _manager.dio.get<ResponseBody>(
              '${_manager.config.aiTagPath}/resize',
              options: Options(responseType: ResponseType.stream),
              queryParameters: {'file': value}))
          .then((body) {
        onProcess?.call(0, body.data?.contentLength ?? 0);
        return body.data != null
            ? stream.addStream(body.data!.stream)
            : stream.addError('empty data');
      }).catchError((e) {
        stream.addError(e);
        _manager.logger.e('download error: $e');
      }, test: (error) => true).whenComplete(() => stream.close());
    } else {
      origin
          .then((value) => _manager.manager.compute(value))
          .then((value) =>
              value != null ? stream.add(value) : stream.addError('empty data'))
          .catchError((e) => <int>[], test: (error) => true)
          .whenComplete(() => stream.close());
    }
    return stream.stream;
  }

  @override
  Future<bool> downloadImages(Gallery gallery,
      {bool usePrefence = true, CancelToken? token}) {
    return _hitomiImpl.downloadImages(gallery,
        usePrefence: usePrefence, token: token);
  }

  @override
  Future<Gallery> fetchGallery(id, {usePrefence = true, CancelToken? token}) {
    return _helper.queryGalleryById(id).catchError(
        (e) => _hitomiImpl.fetchGallery(id, usePrefence: usePrefence),
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
  Future<DataResponse<List<int>>> search(
    List<Label> include, {
    List<Label> exclude = const [],
    int page = 1,
    SortEnum sort = SortEnum.Default,
    CancelToken? token,
  }) async {
    var group = include.groupListsBy((element) => element.runtimeType);
    var excludeGroups = exclude.groupListsBy((element) => element.runtimeType);
    final sql = StringBuffer(
        'select COUNT(*) OVER() AS total_count,g.id from Gallery g where ');
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
              params.addAll([element.type, element.name]);
              if (index != 0) {
                previousValue.write('and ');
              }
              return previousValue
                ..write(
                    'exists (select 1 from GalleryTagRelation r where r.gid = g.id and r.tid = (select id from Tags where type = ? and name = ?))');
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
              params.addAll([element.type, element.name]);
              if (index != 0) {
                previousValue.write('and ');
              }
              return previousValue
                ..write(
                    'not exists (select 1 from GalleryTagRelation r where r.gid = g.id and r.tid = (select id from Tags where type = ? and name = ?))');
            });
            previousValue.write(') and ');
          }
      }
      return previousValue;
    });
    sql.write('1=1');
    switch (sort) {
      case SortEnum.Default:
        sql.write(' order by g.id desc');
      case SortEnum.ID_ASC:
        sql.write(' order by g.id asc');
      case SortEnum.ADD_TIME:
        sql.write(' order by g.date desc');
      // ignore: unreachable_switch_default
      default:
        break;
    }
    sql.write(' limit 25 offset ${(page - 1) * 25}');
    _manager.logger.d('sql is ${sql} parms = ${params}');
    int count = 0;
    return _helper.querySql(sql.toString(), params).then((value) {
      count = value.firstOrNull?['total_count'] ?? 0;
      return value.map((element) => element['id'] as int).toList();
    }).then((value) => DataResponse(value, totalCount: count));
  }

  @override
  Future<DataResponse<List<Gallery>>> viewByTag(Label tag,
      {int page = 1, CancelToken? token, SortEnum? sort}) async {
    var sql = '';
    var params = <dynamic>[];
    if (tag is QueryText) {
      if (tag.name.isNotEmpty) {
        sql =
            'select COUNT(*) OVER() AS total_count,g.* from Gallery g where g.title like ? ';
        params.add('%${tag.name}%');
      } else {
        sql = 'select COUNT(*) OVER() AS total_count,g.* from Gallery g ';
      }
    } else if (tag is TypeLabel) {
      sql =
          'select COUNT(*) OVER() AS total_count,g.* from Gallery g where type =? ';
      params.add(tag.name);
    } else {
      sql =
          'select COUNT(*) OVER() AS total_count,g.id from Gallery g where exists (select 1 from GalleryTagRelation r where r.gid = g.id and r.tid = (select id from Tags where type = ? and name = ?)) ';
      params.addAll([tag.type, tag.name]);
    }
    switch (sort) {
      case SortEnum.ID_ASC:
        sql = '${sql}';
        break;
      case SortEnum.ADD_TIME:
        sql = '${sql} order by date desc';
      default:
        sql = '${sql} order by g.id desc';
        break;
    }
    sql = '$sql limit 25 offset ${(page - 1) * 25}';
    var count = 0;
    _manager.logger.d('$sql with $params');
    return _helper
        .querySqlByCursor(sql, params)
        .then((value) => value.asyncMap((row) {
              if (count <= 0) {
                count = row['total_count'];
              }
              return _helper.queryGalleryById(row['id']);
            }).fold(<Gallery>[], (previous, element) => previous..add(element)))
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
    return fetchGalleryHash(gallery, _manager.down, adHashes: _manager.adHash)
        .then((value) => findDuplicateGalleryIds(
            gallery: gallery,
            helper: _manager.helper,
            threshold: _manager.config.threshold,
            fileHashs: value.value))
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
  // int tag_index_version = 0;
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
  final allowCodeExp = RegExp(r'[\u0800-\u4e00|\u4e00-\u9fa5|30A0-30FF|\w]+');
  _HitomiImpl(this.manager) {
    this.outPut = manager.config.output;
    this.languages = manager.config.languages;
    this.logger = manager.logger;
    this._dio = manager.dio;
    checkInit();
  }

  Future<Gallery> _fetchGalleryJsonById(dynamic id, CancelToken? token) async {
    return _dio
        .httpInvoke<String>('https://ltn.$apiDomain/galleries/$id.js',
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
      try {
        b &= await element(msg);
      } catch (e, stack) {
        logger?.e('_loopCallBack $msg faild $e stack $stack');
      }
    }
    return b;
  }

  @override
  Future<bool> downloadImages(Gallery gallery,
      {usePrefence = true, CancelToken? token}) async {
    await checkInit();
    final id = gallery.id;
    final outPath = outPut;
    Directory dir = gallery.createDir(outPath, createDir: false);
    bool allow = await _loopCallBack(TaskStartMessage(gallery, dir, gallery))
        .catchError((e) => false, test: (error) => true);
    if (!allow) {
      logger?.w('${id} test fiald,skip');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
      await _loopCallBack(DownLoadFinished(gallery, gallery, dir, false));
      return false;
    }
    dir = gallery.createDir(outPath);
    final missImages = <Image>[];
    for (var i = 0; i < gallery.files.length; i++) {
      var success = await _downLoadImage(dir, gallery, i, token);
      if (!success) {
        missImages.add(gallery.files[i]);
      }
    }
    try {
      File(join(dir.path, 'meta.json'))
          .writeAsStringSync(json.encode(gallery), flush: true);
    } catch (e) {
      logger?.e('write json $e');
    }
    return await _loopCallBack(
            DownLoadFinished(missImages, gallery, dir, missImages.isEmpty)) &&
        missImages.isEmpty;
  }

  Future<bool> _downLoadImage(
      Directory dir, Gallery gallery, int index, CancelToken? token) async {
    bool b = false;
    try {
      final referer = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
      Image image = gallery.files[index];
      final out = File(join(dir.path, image.name));
      final url =
          buildImageUrl(image, size: ThumbnaiSize.origin, id: gallery.id);
      var startTime = DateTime.now().millisecondsSinceEpoch;
      int lastTime = startTime;
      b = await _loopCallBack(TaskStartMessage(gallery, out, image)) &&
          (token?.isCancelled ?? false) == false &&
          (!out.existsSync() || out.lengthSync() == 0);
      logger?.d('down image ${image.name} to ${out.path}  $b');
      if (b) {
        var writer = out.openWrite();
        await _dio
            .httpInvoke<ResponseBody>(url,
                headers: buildRequestHeader(url, referer),
                onProcess: (now, total) async {
              final realTime = DateTime.now().millisecondsSinceEpoch;
              if ((realTime - lastTime) >= 250) {
                await _loopCallBack(
                  DownLoadingMessage(gallery, index,
                      now / 1024 / (realTime - startTime) * 1000, now, total),
                );
                lastTime = realTime;
              }
            }, token: token)
            .then((value) => value.stream
                .fold(writer, (previous, element) => previous..add(element)))
            .then((value) async {
              await value.flush();
            })
            .whenComplete(() => writer.close());
      }
      b = out.existsSync() && out.lengthSync() > 0;
      if (!b && out.existsSync() && out.lengthSync() == 0) {
        out.delete();
      }
      await _loopCallBack(DownLoadFinished(image, gallery, out, b));
    } catch (e) {
      logger?.e('down ${gallery.id} $index image faild');
      await _loopCallBack(IlleagalGallery(gallery.id, e.toString(), index));
      b = false;
    }
    return b;
  }

  @override
  Stream<List<int>> fetchImageData(Image image,
      {String refererUrl = 'https://hitomi.la',
      CancelToken? token,
      int id = 0,
      bool translate = false,
      String lang = 'ja',
      ThumbnaiSize size = ThumbnaiSize.smaill,
      void Function(int now, int total)? onProcess}) {
    final stream = StreamController<List<int>>();
    var length = 0;
    checkInit()
        .then((d) => buildImageUrl(image, size: size, id: id))
        .then((url) => _dio
                .httpInvoke<ResponseBody>(url,
                    headers: buildRequestHeader(url, refererUrl),
                    onProcess: translate ? (i, t) => length = t : onProcess,
                    token: token)
                .then((resp) => resp.stream)
                .then((resp) async {
              if (translate) {
                return await _dio
                    .post<ResponseBody>('${manager.config.aiTagPath}/evaluate',
                        data: FormData.fromMap({
                          'file': MultipartFile.fromStream(() => resp, length,
                              filename: image.name,
                              contentType: DioMediaType.parse('image/*')),
                          'lang': lang,
                          'process': 'translate'
                        }),
                        options: Options(responseType: ResponseType.stream),
                        onReceiveProgress: onProcess)
                    .then((resp) => resp.data!.stream);
              }
              return resp;
            }).then((resp) => stream.addStream(resp)))
        .catchError((e) => stream.addError(e), test: (error) => true)
        .whenComplete(() => stream.close());
    return stream.stream;
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
              "https://w${_subDomainIndex(image.hash) + 1}.$apiDomain/${code}/${_parseLast3HashCode(image.hash)}/${image.hash}.webp";
        }
      case ThumbnaiSize.smaill:
        sizeStr = 'webpsmallsmalltn';
        url =
            "https://${_getUserInfo(image.hash, 'tn')}.$apiDomain/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${image.hash}.webp";
      case ThumbnaiSize.medium:
        sizeStr = 'webpsmalltn';
        url =
            "https://${_getUserInfo(image.hash, 'tn')}.$apiDomain/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${image.hash}.webp";
      case ThumbnaiSize.big:
        sizeStr = 'webpbigtn';
        url =
            "https://${_getUserInfo(image.hash, 'tn')}.$apiDomain/$sizeStr/${lastThreeCode.substring(2)}/${lastThreeCode.substring(0, 2)}/${image.hash}.webp";
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
        .where((element) => allowCodeExp.hasMatch(element))
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
    var data =
        await fetchGalleryHashFromNet(gallery, manager.down, token, false)
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
        .asyncMap((event) =>
            fetchGalleryHashFromNet(event, manager.down, token, false))
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
      SortEnum sort = SortEnum.Default,
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
    if (sort == SortEnum.ID_ASC) {
      includeIds = includeIds.reversed.toList();
    }
    logger?.i('search left id ${includeIds.length}');
    return DataResponse(includeIds, totalCount: includeIds.length);
  }

  Future<List<int>> _fetchIdsByTag(Label tag,
      {Language? language, CancelToken? token}) {
    if (tag is QueryText) {
      return _fetchQuery(
              'https://ltn.$apiDomain/galleriesindex/galleries.${galleries_index_version}.index',
              tag.name.toLowerCase(),
              token)
          .then((value) => _fetchData(value, token));
    } else {
      final useLanguage = language?.name ?? 'all';
      String url;
      if (tag is Language) {
        url = 'https://ltn.$apiDomain/n/${tag.urlEncode()}.nozomi';
      } else {
        url = 'https://ltn.$apiDomain/n/${tag.urlEncode()}-$useLanguage.nozomi';
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
    return _dio
        .httpInvoke<List<dynamic>>(
            'https://tagindex.hitomi.la/global${key.codeUnits.fold('', (acc, char) => acc + '/' + String.fromCharCode(char))}',
            headers: buildRequestHeader(
                'https://ltn.$apiDomain', 'https://hitomi.la/'))
        .then((value) => value
            .map((element) => element as List)
            .map((m) => fromString(m[2], m[0]))
            .toList())
        .then((value) => manager.collectedInfo(value))
        .then((value) => value.values.toList());
  }

  // Future<List<Label>> _fetchTagData(
  //     MapEntry<int, int> tuple, CancelToken? token) async {
  //   await checkInit();
  //   final url = 'https://ltn.hitomi.la/tagindex/global.$tag_index_version.data';
  //   return await _dio
  //       .httpInvoke<List<int>>(url,
  //           headers: buildRequestHeader(url, 'https://hitomi.la/',
  //               range: MapEntry(tuple.key, tuple.key + tuple.value - 1)),
  //           token: token)
  //       .then((value) {
  //     final view = _DataView(value);
  //     var number = view.getData(4);
  //     final sb = StringBuffer();
  //     List<Label> list = [];
  //     logger?.d('found $number');
  //     for (int i = 0; i < number; i++) {
  //       int len = view.getData(4);
  //       for (var index = 0; index < len; index++) {
  //         sb.writeCharCode(view.getData(1));
  //       }
  //       String type = sb.toString().replaceAll('/#', '');
  //       sb.clear();
  //       len = view.getData(4);
  //       for (var index = 0; index < len; index++) {
  //         sb.writeCharCode(view.getData(1));
  //       }
  //       String name = sb.toString();
  //       sb.clear();
  //       view.getData(4);
  //       list.add(fromString(type, name));
  //     }
  //     return list;
  //   });
  // }

  Future<MapEntry<int, int>> _fetchQuery(
      String url, String word, CancelToken? token) async {
    await checkInit();
    logger?.d('$url with $word');
    final hash =
        sha256.convert(Utf8Encoder().convert(word)).bytes.take(4).toList();
    return _fetchNode(url, token: token)
        .then((value) => _netBTreeSearch(url, value, hash, token));
  }

  Future<MapEntry<int, int>> _netBTreeSearch(
      String url, _Node node, List<int> hashKey, CancelToken? token) async {
    var tuple = MapEntry(false, node.keys.length);
    for (var i = 0; i < node.keys.length; i++) {
      var v = hashKey.compareTo(node.keys[i]);
      if (v <= 0) {
        tuple = MapEntry(v == 0, i);
        break;
      }
    }
    if (tuple.key) {
      return node.datas[tuple.value];
    } else if (node.subnode_addresses.any((element) => element != 0) &&
        node.subnode_addresses[tuple.value] != 0) {
      return _netBTreeSearch(
          url,
          await _fetchNode(url, start: node.subnode_addresses[tuple.value]),
          hashKey,
          token);
    }
    throw 'not founded';
  }

  Future<List<int>> _fetchData(
      MapEntry<int, int> tuple, CancelToken? token) async {
    await checkInit();
    final url =
        'https://ltn.$apiDomain/galleriesindex/galleries.${galleries_index_version}.data';
    return await _dio
        .httpInvoke<List<int>>(url,
            headers: buildRequestHeader(url, 'https://hitomi.la/',
                range: MapEntry(tuple.key, tuple.key + tuple.value - 1)),
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
        'https://hitomi.la/${tag.urlEncode()}${tag is Language ? '' : '-all'}.html';
    if (page > 1) {
      referer += '?page=$page';
    }
    final dataUrl =
        'https://ltn.$apiDomain/${tag.urlEncode()}${tag is Language ? '' : '-all'}.nozomi';
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
        .httpInvoke<String>('https://ltn.$apiDomain/gg.js')
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
            'https://ltn.$apiDomain/galleriesindex/version?_=${DateTime.now().millisecondsSinceEpoch}')
        .then((value) => int.parse(value));
    // tag_index_version = await _dio
    //     .httpInvoke<String>(
    //         'https://ltn.hitomi.la/tagindex/version?_=${DateTime.now().millisecondsSinceEpoch}')
    //     .then((value) => int.parse(value));
  }

  Future<void> checkInit() async {
    if (_timer == null) {
      await initData();
      _timer = Timer.periodic(
          Duration(minutes: 30),
          (timer) => initData().catchError(
              (e) => logger?.e(e, time: DateTime.now()),
              test: (error) => true));
    }
  }

  String _getUserInfo(String hash, String postFix) {
    final userInfo = ['a', 'b'];
    return userInfo[_subDomainIndex(hash)] + postFix;
  }

  int _subDomainIndex(String hash) {
    final code = _parseLast3HashCode(hash);
    var useIndex = index - (codes.any((element) => element == code) ? 1 : 0);
    return useIndex.abs();
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
  List<MapEntry<int, int>> datas = [];
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
      datas.add(MapEntry(start, end));
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
  Stream<List<int>> fetchImageData(Image image,
      {String refererUrl = 'https://hitomi.la',
      CancelToken? token,
      int id = 0,
      bool translate = false,
      String lang = 'ja',
      ThumbnaiSize size = ThumbnaiSize.smaill,
      void Function(int now, int total)? onProcess}) {
    final stream = StreamController<List<int>>();
    dio
        .get<ResponseBody>('$bashHttp/fetchImageData',
            queryParameters: {
              'hash': image.hash,
              'name': image.name,
              'referer': refererUrl,
              'size': size.name,
              'id': id,
              'translate': translate,
              'lang': lang,
              'local': localDb
            },
            options: Options(responseType: ResponseType.stream),
            onReceiveProgress: onProcess)
        .then((value) => stream.addStream(value.data!.stream))
        .then((value) => stream.close())
        .catchError((e) {
      stream.addError(e);
      stream.close();
    }, test: (error) => true);
    return stream.stream;
  }

  @override
  void registerCallBack(Future<bool> Function(Message msg) callBack) {}

  @override
  void removeCallBack(Future<bool> Function(Message msg) callBack) {}

  @override
  Future<DataResponse<List<int>>> search(List<Label> include,
      {List<Label> exclude = const [],
      int page = 1,
      SortEnum sort = SortEnum.Default,
      CancelToken? token}) {
    return dio
        .post<String>('$bashHttp/proxy/search',
            data: json.encode({
              'include': include,
              'excludes': exclude,
              'page': page,
              'auth': auth,
              'sort': sort.name,
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
