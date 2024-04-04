import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dcache/dcache.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/multi_paltform.dart';
import 'package:path/path.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tuple/tuple.dart';
import 'package:dio/dio.dart' show ResponseBody;
import 'gallery_util.dart';

final defaultRespHeader = {
  HttpHeaders.accessControlAllowOriginHeader: '*',
  HttpHeaders.accessControlAllowMethodsHeader: 'GET, POST',
  HttpHeaders.accessControlAllowHeadersHeader: '*',
  HttpHeaders.accessControlAllowCredentialsHeader: 'true',
  HttpHeaders.contentTypeHeader: 'application/json'
};

class _TaskWarp {
  final TaskManager _manager;
  final _cache = SimpleCache<Label, MapEntry<int, String>?>(
      storage: InMemoryStorage(1024));
  final Router router = Router();
  late Future<MapEntry<String, dynamic>?> Function(String id, String hash)
      thumbFunctin;
  late Future<MapEntry<String, dynamic>?> Function(String id, String hash)
      originFunctin;
  late Hitomi localHitomi;
  _TaskWarp(this._manager) {
    router
      ..get('/', (req) => Response.ok('ok'))
      ..post('/translate', _translate)
      ..options('/translate', _optionsOk)
      ..post('/addTask', _addTask)
      ..options('/addTask', _optionsOk)
      ..post('/listTask', _listTask)
      ..options('/listTask', _optionsOk)
      ..post('/checkId', _checkId)
      ..options('/checkId', _optionsOk)
      ..post('/fetchTag/<key>', _fetchTag)
      ..options('/fetchTag/<key>', _optionsOk)
      ..post('/proxy/<method>', _proxy)
      ..options('/proxy/<method>',
          (req) => Response.ok(null, headers: defaultRespHeader))
      ..get('/thumb/<gid>/<hash>', _thumb)
      ..options(
          '/thumb/<gid>/<hash>',
          (req) => Response.ok(null, headers: {
                ...defaultRespHeader,
                HttpHeaders.contentTypeHeader: 'application/octet-stream'
              }))
      ..get('/image/<gid>/<hash>', _image)
      ..options(
          '/image/<gid>/<hash>',
          (req) => Response.ok(null, headers: {
                ...defaultRespHeader,
                HttpHeaders.contentTypeHeader: 'application/octet-stream'
              }))
      ..post('/excludes', (req) async {
        var succ = await _authToken(req);
        if (succ.item1) {
          return Response.ok(json.encode(_manager.config.excludes),
              headers: defaultRespHeader);
        }
        return Response.unauthorized('unauth');
      });
    localHitomi = createHitomi(_manager, true, 'http://127.0.0.1:7890');
    thumbFunctin = (id, hash) => _manager.helper
        .querySqlByCursor(
            'select gf.thumb,gf.name from GalleryFile gf where gf.gid=? and hash=?',
            [
              id,
              hash
            ])
        .asyncMap((event) =>
            MapEntry<String, List<int>>(event['name'], event['thumb']))
        .firstOrNull;

    originFunctin = (id, hash) => _manager.helper.querySqlByCursor(
            'select gf.name,g.path from Gallery g left join GalleryFile gf on g.id=gf.gid where g.id=? and gf.hash=?',
            [id, hash]).asyncMap((event) async {
          String fileName = event['name'];
          String path = join(_manager.config.output, event['path'], fileName);
          return MapEntry<String, Stream<List<int>>>(
              fileName, File(path).openRead());
        }).firstOrNull;
  }

  Future<Response> _optionsOk(Request req) async {
    return Response.ok(null, headers: {
      ...defaultRespHeader,
      HttpHeaders.contentTypeHeader: 'application/json'
    });
  }

  List<Label> _mapFromRequest(List<dynamic> params) {
    return params
        .map((e) {
          return json.decode(e);
        })
        .map((e) => fromString(e['type'], e['name']))
        .toList();
  }

  Future<Response> _proxy(Request req) async {
    final task = await _authToken(req);
    final method = req.params['method'];
    if (task.item1 && method?.isNotEmpty == true) {
      switch (method!) {
        case 'fetchGallery':
          {
            var id = task.item2['id'];
            return (task.item2['local'] == true
                    ? localHitomi
                    : _manager.getApiDirect())
                .fetchGallery(id, usePrefence: task.item2['usePrefence'])
                .then((value) => Response.ok(json.encode(value),
                    headers: defaultRespHeader));
          }
        case 'search':
          {
            List<dynamic> tags = task.item2['include'];
            List<dynamic>? exclude = task.item2['excludes'];
            return (task.item2['local'] == true
                    ? localHitomi
                    : _manager.getApiDirect())
                .search(_mapFromRequest(tags),
                    exclude: exclude != null
                        ? _mapFromRequest(exclude)
                        : _manager.config.excludes,
                    page: task.item2['page'] ?? 1)
                .then((value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader));
          }
        case 'viewByTag':
          {
            List<dynamic> tags = task.item2['tags'];
            var querySort = task.item2['sort'];
            SortEnum? sort = SortEnum.values
                .firstWhereOrNull((element) => element.name == querySort);
            return (task.item2['local'] == true
                    ? localHitomi
                    : _manager.getApiDirect())
                .viewByTag(_mapFromRequest(tags).first,
                    page: task.item2['page'] ?? 1, sort: sort)
                .then((value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader));
          }
        case 'findSimilar':
          {
            String string = task.item2['gallery'];
            return (task.item2['local'] == true
                    ? localHitomi
                    : _manager.getApiDirect())
                .findSimilarGalleryBySearch(Gallery.fromJson(string))
                .then((value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader));
          }
        case 'fetchImageData':
          {
            Image image = Image.fromJson(task.item2['image']);
            if (task.item2['local'] == true) {
              return _loadImageInner(
                  task.item2['id'],
                  image.hash,
                  null,
                  task.item2['size'] == 'smaill'
                      ? thumbFunctin
                      : originFunctin);
            } else {
              return _manager
                  .getApiDirect()
                  .fetchImageData(image,
                      refererUrl: task.item2['referer'] ?? '',
                      size: ThumbnaiSize.values.firstWhere(
                          (element) => element.name == task.item2['size']),
                      id: task.item2['id'])
                  .then((value) => Response.ok(value));
            }
          }
        default:
          {
            return Response.badRequest();
          }
      }
    }
    return Response.unauthorized('unauth');
  }

  Future<Tuple2<bool, Map<String, dynamic>>> _authToken(Request req) async {
    var posted = await req.readAsString();
    if (posted.isNotEmpty) {
      Map<String, dynamic> body = json.decode(posted);
      return Tuple2(body['auth'] == _manager.config.auth, body);
    }
    return Tuple2(false, Map());
  }

  Future<Response> _loadImageInner<T>(
      String id,
      String? hash,
      String? before,
      Future<MapEntry<String, T>?> Function(String id, String hash)
          fetch) async {
    if (hash == null || hash.length != 64) {
      return Response.badRequest();
    }
    if (before != null && before == hash) {
      return Response.notModified();
    }
    var data = await fetch(id, hash);
    if (data != null) {
      var fileName = data.key;
      return Response.ok(data.value, headers: {
        ...defaultRespHeader,
        HttpHeaders.contentTypeHeader:
            'image/${extension(fileName).substring(1)}',
        HttpHeaders.cacheControlHeader: 'public, max-age=259200',
        HttpHeaders.etagHeader: hash,
      });
    }
    return Response.notFound(null);
  }

  Future<Response> _thumb(Request req) async {
    var hash = req.params['hash'] ?? '';
    var id = req.params['gid']!;
    var size = req.url.queryParameters['size'] ?? 'medium';
    if (req.url.queryParameters['local'] == '1') {
      return _loadImageInner(
          id, hash, req.headers['If-None-Match'], thumbFunctin);
    }
    var url = _manager.getApiDirect().buildImageUrl(
        Image(
            hash: hash, hasavif: 0, width: 0, height: 0, haswebp: 0, name: ''),
        size:
            ThumbnaiSize.values.firstWhere((element) => element.name == size));
    return _manager.dio
        .httpInvoke<ResponseBody>(url,
            headers: buildRequestHeader(
                url, 'https://hitomi.la/doujinshi/test-${id}.html'),
            logger: _manager.logger)
        .then((value) => Response.ok(value.stream, headers: {
              ...defaultRespHeader,
              HttpHeaders.contentTypeHeader: 'image/webp',
              HttpHeaders.cacheControlHeader: 'public, max-age=259200',
              HttpHeaders.etagHeader: hash,
            }));
  }

  Future<Response> _image(Request req) async {
    var hash = req.params['hash'] ?? '';
    var id = req.params['gid']!;
    if (req.url.queryParameters['local'] == '1') {
      return _loadImageInner(req.params['gid']!, hash,
          req.headers['If-None-Match'], originFunctin);
    }
    var url = _manager.getApiDirect().buildImageUrl(
        Image(
            hash: hash, hasavif: 0, width: 0, height: 0, haswebp: 0, name: ''),
        size: ThumbnaiSize.origin);
    return _manager.dio
        .httpInvoke<ResponseBody>(url,
            headers: buildRequestHeader(
                url, 'https://hitomi.la/doujinshi/test-${id}.html'),
            logger: _manager.logger)
        .then((value) => Response.ok(value.stream, headers: {
              ...defaultRespHeader,
              HttpHeaders.contentTypeHeader: 'image/webp',
              HttpHeaders.cacheControlHeader: 'public, max-age=259200',
              HttpHeaders.etagHeader: hash,
            }));
  }

  Future<Response> _translate(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      Set<Label> keys = (task.item2['tags'] as List<dynamic>)
          .map((e) =>
              (e is Map<String, dynamic>) ? e : (json.decode(e.toString())))
          .map((e) => fromString(e['type'], e['name']))
          .where((element) => element.runtimeType != QueryText)
          .toSet();
      final r = await _collectionTags(keys.toList());
      return Response.ok(json.encode(r), headers: defaultRespHeader);
    }
    return Response.unauthorized('unauth');
  }

  Future<List<Map<String, dynamic>>> _collectionTags(List<Label> keys) async {
    await keys
        .where((element) => !_cache.containsKey(element))
        .groupListsBy((element) => element.localSqlType)
        .entries
        .asStream()
        .forEach((entry) async {
      await _manager.helper
          .selectSqlMultiResultAsync(
              'select count(1) as count,date as date from Gallery where json_value_contains(${entry.key},?,?)=1',
              entry.value
                  .where((element) => element.runtimeType != TypeLabel)
                  .map((e) => [e.name, e.type])
                  .toList())
          .then((value) {
        return value.entries.fold(_cache, (previousValue, element) {
          final row = element.value.firstOrNull;
          if (row != null && row['date'] != null) {
            previousValue[fromString(element.key[1], element.key[0])] =
                MapEntry(
                    row['count'],
                    DateTime.fromMillisecondsSinceEpoch(row['date'])
                        .toString());
          }
          return previousValue;
        });
      });
    });
    final r = await _manager
        .translateLabel(keys)
        .then((value) => value.entries.map((entry) {
              var key = entry.key;
              var value = entry.value;
              final cache = _cache[key];
              if (cache != null) {
                value['count'] = cache.key;
                value['date'] = cache.value;
              }
              return value;
            }).toList());
    return r;
  }

  Future<Response> _addTask(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      _manager.parseCommandAndRun(task.item2['task']);
      return Response.ok(json.encode({'success': true}),
          headers: defaultRespHeader);
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _listTask(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      Map<String, dynamic> r = await _manager.parseCommandAndRun('-l');
      r['success'] = true;
      return Response.ok(json.encode(r), headers: defaultRespHeader);
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _checkId(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      int id = task.item2['id'];
      var row = await _manager.helper
          .queryGalleryById(id)
          .then((value) => value.firstOrNull);
      if (row != null) {
        return Response.ok(
            json.encode({
              'id': id,
              'value': [id]
            }),
            headers: defaultRespHeader);
      }
      return _manager
          .getApiDirect()
          .fetchGallery(id, usePrefence: false)
          .then((value) => value
                  .createDir(_manager.config.output, createDir: false)
                  .existsSync()
              ? readGalleryFromPath(value
                      .createDir(_manager.config.output, createDir: false)
                      .path)
                  .then((value) => [value.id])
              : findDuplicateGalleryIds(
                  value, _manager.helper, _manager.getApiDirect(),
                  logger: _manager.logger))
          .then((value) => {'id': id, 'value': value})
          .then((value) =>
              Response.ok(json.encode(value), headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _fetchTag(Request req) async {
    var key = Uri.decodeComponent(req.params['key'] ?? '');
    if (key.isEmpty) {
      return Response.badRequest();
    }
    final task = await _authToken(req);
    if (task.item1) {
      return localHitomi.fetchSuggestions(key).then((value) =>
          Response.ok(json.encode(value), headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }
}

Future<HttpServer> run_server(TaskManager manager) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests(
          logger: (message, isError) =>
              isError ? manager.logger.e(message) : manager.logger.d(message)))
      .addHandler(_TaskWarp(manager).router);
  // For running in containers, we respect the PORT environment variable.
  final socketPort = int.parse(Platform.environment['PORT'] ?? '7890');
  final servers = await serve(handler, InternetAddress.anyIPv6, socketPort,
      poweredByHeader: 'hitomi');
  servers.autoCompress = true;
  servers.defaultResponseHeaders.clear();
  manager.logger
      .i('Server run on http://${servers.address.address}:${servers.port}');
  return servers;
}
