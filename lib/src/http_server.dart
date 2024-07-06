import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/multi_paltform.dart';
import 'package:path/path.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:tuple/tuple.dart';

final defaultRespHeader = {
  HttpHeaders.accessControlAllowOriginHeader: '*',
  HttpHeaders.accessControlAllowMethodsHeader: 'GET, POST',
  HttpHeaders.accessControlAllowHeadersHeader: '*',
  HttpHeaders.accessControlAllowCredentialsHeader: 'true',
  HttpHeaders.contentTypeHeader: 'application/json'
};

class _TaskWarp {
  final TaskManager _manager;
  final Router router = Router();
  late Hitomi localHitomi;
  _TaskWarp(this._manager) {
    router
      ..get('/', (req) => Response.movedPermanently('/index.html'))
      ..post('/translate', _translate)
      ..get('/test', (req) => Response.ok('ok'))
      ..options('/translate', _optionsOk)
      ..post('/addTask', _addTask)
      ..options('/addTask', _optionsOk)
      ..post('/addAdMark', _addAdMark)
      ..options('/addAdMark', _optionsOk)
      ..post('/listTask', _listTask)
      ..options('/listTask', _optionsOk)
      ..post('/checkId', _checkId)
      ..options('/checkId', _optionsOk)
      ..post('/fetchTag/<key>', _fetchTag)
      ..options('/fetchTag/<key>', _optionsOk)
      ..post('/proxy/<method>', _proxy)
      ..options('/proxy/<method>',
          (req) => Response.ok(null, headers: defaultRespHeader))
      ..get('/fetchImageData', _image)
      ..options(
          '/fetchImageData',
          (req) => Response.ok(null, headers: {
                ...defaultRespHeader,
                HttpHeaders.contentTypeHeader: 'application/octet-stream'
              }))
      ..post('/cancel', _cancel)
      ..options('/cancel', _optionsOk)
      ..post('/delete', _delete)
      ..options('/delete', _optionsOk)
      ..options('/adList', _optionsOk)
      ..get('/adList', (req) {
        return Response.ok(json.encode(_manager.adImage),
            headers: defaultRespHeader);
      })
      ..get('/ip', (req) {
        return NetworkInterface.list()
            .then((value) => value.firstOrNull?.addresses
                .where((element) =>
                    element.type == InternetAddressType.IPv6 &&
                    element.address.startsWith('2'))
                .map((e) => e.address)
                .toList())
            .then((rep) =>
                Response.ok(json.encode(rep), headers: defaultRespHeader));
      })
      ..post('/excludes', (req) async {
        var succ = await _authToken(req);
        if (succ.item1) {
          return Response.ok(json.encode(_manager.config.excludes),
              headers: defaultRespHeader);
        }
        return Response.unauthorized('unauth');
      });
    localHitomi = createHitomi(_manager, true, 'http://127.0.0.1:7890');
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
            var id = req.url.queryParameters['id'];
            var local = req.url.queryParameters['local'] == 'true';
            var usePrefence = req.url.queryParameters['usePrefence'] == 'true';
            return (local ? localHitomi : _manager.getApiDirect())
                .fetchGallery(id, usePrefence: usePrefence)
                .then((value) => Response.ok(json.encode(value),
                    headers: defaultRespHeader));
          }
        case 'search':
          {
            List<dynamic> tags = task.item2['include'];
            List<dynamic>? exclude = task.item2['excludes'];
            var querySort = task.item2['sort'];
            SortEnum sort = SortEnum.values
                    .firstWhereOrNull((element) => element.name == querySort) ??
                SortEnum.Default;
            return (task.item2['local'] == true
                    ? localHitomi
                    : _manager.getApiDirect())
                .search(_mapFromRequest(tags),
                    exclude: exclude != null
                        ? _mapFromRequest(exclude)
                        : _manager.config.excludes,
                    sort: sort,
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
        default:
          {
            _manager.logger.d('method $method');
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
      Future<Map<String, dynamic>?> Function(String id, String hash)
          fetch) async {
    if (hash == null || hash.length != 64) {
      return Response.badRequest();
    }
    if (before != null && before == hash) {
      return Response.notModified();
    }
    var data =
        await fetch(id, hash).catchError((e) => null, test: ((error) => true));
    if (data != null) {
      var fileName = data['name'];
      return Response.ok(data['data'], headers: {
        ...defaultRespHeader,
        HttpHeaders.contentLengthHeader: data['length'],
        HttpHeaders.contentTypeHeader:
            'image/${extension(fileName).substring(1)}',
        HttpHeaders.cacheControlHeader: 'public, max-age=259200',
        HttpHeaders.etagHeader: hash,
      });
    }
    return Response.notFound(null);
  }

  Future<Response> _image(Request req) async {
    var id = req.url.queryParameters['id'];
    var hash = req.url.queryParameters['hash'];
    var name = req.url.queryParameters['name'];
    var size = req.url.queryParameters['size'];
    var local = req.url.queryParameters['local'] == 'true';
    if (id == null ||
        (hash?.length ?? 0) != 64 ||
        size == null ||
        name == null) {
      _manager.logger.d('$id $hash $name $size $local');
      return Response.badRequest();
    }
    var before = req.headers['If-None-Match'];
    if (before != null && before == hash) {
      return Response.notModified();
    }
    return _manager
        .getApiDirect(local: local)
        .fetchImageData(
            Image(
                hash: hash!,
                hasavif: 0,
                width: 0,
                haswebp: 0,
                name: name,
                height: 0),
            refererUrl: req.url.queryParameters['referer'] ?? '',
            size: ThumbnaiSize.values
                .firstWhere((element) => element.name == size),
            id: int.parse(id))
        .then((value) => Response.ok(value, headers: {
              ...defaultRespHeader,
              HttpHeaders.cacheControlHeader: 'public, max-age=259200',
              HttpHeaders.etagHeader: hash,
              HttpHeaders.contentTypeHeader:
                  'image/${extension(name).substring(1)}',
              HttpHeaders.contentLengthHeader: value.length.toString(),
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

      return _manager
          .translateLabel(keys.toList())
          .then((value) => value.values.toList())
          .then((value) =>
              Response.ok(json.encode(value), headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _addTask(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.item1 && (ip.isEmpty || ip.startsWith('192.168'))) {
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
      return _manager
          .checkExistsId(id)
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

  Future<Response> _cancel(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.item1 && (ip.isEmpty || ip.startsWith('192.168'))) {
      return _manager.parseCommandAndRun('-p ${task.item2['id']}').then(
          (value) => Response.ok(json.encode({'success': value}),
              headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _delete(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.item1 && (ip.isEmpty || ip.startsWith('192.168'))) {
      return _manager.parseCommandAndRun('-d ${task.item2['id']}').then(
          (value) => Response.ok(json.encode({'success': value}),
              headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _addAdMark(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.item1 && (ip.isEmpty || ip.startsWith('192.168'))) {
      return (task.item2['mask'] as List<dynamic>)
          .asStream()
          .asyncMap((event) => _manager.parseCommandAndRun('--admark ${event}'))
          .fold(true, (previous, element) => previous && element)
          .then((value) => Response.ok(json.encode({'success': value}),
              headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }
}

SecurityContext getSecurityContext() {
  // Bind with a secure HTTPS connection
  final chain = Platform.script.resolve('../server.crt').toFilePath();
  final key = Platform.script.resolve('../server.key').toFilePath();

  return SecurityContext()
    ..useCertificateChain(chain)
    ..usePrivateKey(key, password: 'bai551302');
}

Future<HttpServer> run_server(TaskManager manager) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  // Configure a pipeline that logs requests.
  Handler? staticHandle;
  if (Directory('web').existsSync()) {
    staticHandle = createStaticHandler('web', defaultDocument: 'index.html');
  }
  // Handler webSocket = webSocketHandler((webSocket) {
  //   webSocket.stream.listen((message) {
  //     webSocket.sink.add("echo $message");
  //   });
  // });
  final handler = Pipeline()
      .addMiddleware(logRequests(
          logger: (message, isError) =>
              isError ? manager.logger.e(message) : manager.logger.d(message)))
      .addMiddleware((innerHandler) => (req) {
            return Future.sync(() => innerHandler(req)).then((value) =>
                value.statusCode == 404 && staticHandle != null
                    ? staticHandle(req)
                    : value);
          })
      // .addMiddleware((innerHandler) => (req) {
      //       webSocket(req);
      //       return innerHandler(req);
      //     })
      .addHandler(_TaskWarp(manager).router);
  // For running in containers, we respect the PORT environment variable.
  final socketPort = int.parse(Platform.environment['PORT'] ?? '7890');
  final servers = await serve(handler, InternetAddress.anyIPv6, socketPort,
      poweredByHeader: 'ayaka');
  servers.autoCompress = true;
  manager.logger
      .i('Server run on http://${servers.address.address}:${servers.port}');
  return servers;
}
