import 'dart:async';
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
import 'package:shelf_web_socket/shelf_web_socket.dart';

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
      ..get(
          '/test',
          (req) => Response.ok(
              json.encode(
                  {'success': true, 'feature': _manager.config.aiTagPath}),
              headers: defaultRespHeader))
      ..options('/translate', _optionsOk)
      ..post('/addTask', _addTask)
      ..options('/addTask', _optionsOk)
      ..post('/sync', _sync)
      ..options('/sync', _optionsOk)
      ..post('/checkId', _checkId)
      ..options('/checkId', _optionsOk)
      ..get('/suggest', (Request req) {
        var id = req.url.queryParameters['id'] ?? '';
        if (id.isEmpty == true || int.tryParse(id) == null) {
          return Response.badRequest(body: 'missing id');
        }
        return _manager.findSugguestGallery(id.toInt()).then(
            (ids) => Response.ok(json.encode(ids), headers: defaultRespHeader));
      })
      ..options('/suggest', _optionsOk)
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
        if (succ.key) {
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
    if (task.key && method?.isNotEmpty == true) {
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
            List<dynamic> tags = task.value['include'];
            List<dynamic>? exclude = task.value['excludes'];
            var querySort = task.value['sort'];
            SortEnum sort = SortEnum.values
                    .firstWhereOrNull((element) => element.name == querySort) ??
                SortEnum.Default;
            return (task.value['local'] == true
                    ? localHitomi
                    : _manager.getApiDirect())
                .search(_mapFromRequest(tags),
                    exclude: exclude != null
                        ? _mapFromRequest(exclude)
                        : _manager.config.excludes,
                    sort: sort,
                    page: task.value['page'] ?? 1)
                .then((value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader));
          }
        case 'viewByTag':
          {
            List<dynamic> tags = task.value['tags'];
            var querySort = task.value['sort'];
            SortEnum? sort = SortEnum.values
                .firstWhereOrNull((element) => element.name == querySort);
            return (task.value['local'] == true
                    ? localHitomi
                    : _manager.getApiDirect())
                .viewByTag(_mapFromRequest(tags).first,
                    page: task.value['page'] ?? 1, sort: sort)
                .then((value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader));
          }
        case 'findSimilar':
          {
            String string = task.value['gallery'];
            return (task.value['local'] == true
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

  Future<MapEntry<bool, Map<String, dynamic>>> _authToken(Request req) async {
    var posted = await req.readAsString();
    if (posted.isNotEmpty) {
      Map<String, dynamic> body = json.decode(posted);
      return MapEntry(body['auth'] == _manager.config.auth, body);
    }
    return MapEntry(false, Map());
  }

  Future<Response> _image(Request req) async {
    var id = req.url.queryParameters['id'];
    var hash = req.url.queryParameters['hash'];
    var name = req.url.queryParameters['name'];
    var size = req.url.queryParameters['size'];
    var local = req.url.queryParameters['local'] == 'true';
    var translate = req.url.queryParameters['translate'] == 'true';
    var lang = req.url.queryParameters['lang'] ?? 'ja';
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
            Image(hash: hash!, hasavif: 0, width: 0, name: name, height: 0),
            refererUrl: req.url.queryParameters['referer'] ?? '',
            size: ThumbnaiSize.values
                .firstWhere((element) => element.name == size),
            lang: lang,
            translate: translate,
            id: int.parse(id))
        .fold(<int>[], (acc, l) => acc..addAll(l)).then(
            (value) => Response.ok(Stream.value(value), headers: {
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
    if (task.key) {
      Set<Label> keys = (task.value['tags'] as List<dynamic>)
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
    if (task.key && (ip.isEmpty || isLocalOrLAN(InternetAddress(ip)))) {
      _manager.parseCommandAndRun(task.value['task']);
      return Response.ok(json.encode({'success': true}),
          headers: defaultRespHeader);
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _checkId(Request req) async {
    final task = await _authToken(req);
    if (task.key) {
      int id = task.value['id'];
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
    if (task.key) {
      return localHitomi.fetchSuggestions(key).then((value) =>
          Response.ok(json.encode(value), headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _cancel(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.key && (ip.isEmpty || isLocalOrLAN(InternetAddress(ip)))) {
      return _manager.parseCommandAndRun('-p ${task.value['id']}').then(
          (value) => Response.ok(json.encode({'success': value}),
              headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _delete(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.key && (ip.isEmpty || isLocalOrLAN(InternetAddress(ip)))) {
      return _manager.parseCommandAndRun('-d ${task.value['id']}').then(
          (value) => Response.ok(json.encode({'success': value}),
              headers: defaultRespHeader));
    }
    return Response.unauthorized('unauth');
  }

  bool isLocalOrLAN(InternetAddress address) {
    // 检查环回地址
    if (address.isLoopback) return true;

    if (address.type == InternetAddressType.IPv4) {
      final bytes = address.rawAddress;
      // 检查IPv4私有地址和链路本地地址
      if (bytes.length == 4) {
        final b0 = bytes[0];
        final b1 = bytes[1];
        // 10.0.0.0/8
        if (b0 == 10) return true;
        // 172.16.0.0/12
        if (b0 == 172 && b1 >= 16 && b1 <= 31) return true;
        // 192.168.0.0/16
        if (b0 == 192 && b1 == 168) return true;
        // 169.254.0.0/16 (链路本地地址)
        if (b0 == 169 && b1 == 254) return true;
      }
      return false;
    } else if (address.type == InternetAddressType.IPv6) {
      final bytes = address.rawAddress;
      if (bytes.length == 16) {
        // 检查唯一本地地址 (fc00::/7)
        if ((bytes[0] & 0xFE) == 0xFC) return true;

        // 检查链路本地地址 (fe80::/10)
        final firstTwoBytes = (bytes[0] << 8) | bytes[1];
        if (firstTwoBytes >= 0xFE80 && firstTwoBytes <= 0xFEBF) {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  Future<Response> _sync(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger
        .d('real ip $ip ${task.value['mark']} ${task.value['content'].length}');
    if (task.key && (ip.isEmpty || isLocalOrLAN(InternetAddress(ip)))) {
      int mark = task.value['mark'];
      bool returnValue = task.value['returnValue'] ?? false;
      List<dynamic> content = task.value['content'];
      if (mark == admarkMask) {
        return _manager
            .addAdMark(content.map((e) => e as String).toList())
            .then((value) => Response.ok(
                json.encode({
                  'success': value,
                  'content': returnValue ? _manager.adImage : []
                }),
                headers: defaultRespHeader));
      } else if ([readHistoryMask, bookMarkMask, lateReadMark].contains(mark)) {
        return _manager
            .manageUserLog(content.map((e) => e as int).toList(), mark)
            .then((v) async => returnValue
                ? await _manager.helper
                    .querySql(
                        'select id,mark,type,content from UserLog where type = $mark')
                    .then((set) => set.map((r) => r).toList())
                : [])
            .then((value) => Response.ok(
                json.encode({'success': true, 'content': value}),
                headers: defaultRespHeader));
      }
      return Response.badRequest();
    }
    return Response.unauthorized('Unauthorized');
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
  Handler webSocket = webSocketHandler((webSocket, protocol) {
    Stream stream = webSocket.stream;
    final Function(Map<String, dynamic>) observer = (msg) {
      webSocket.sink.add(json.encode(msg));
    };
    manager.logger.d('income websocket');
    stream.listen((message) {
      manager.logger.d('receive message $message');
      try {
        var msg = json.decode(message) as Map<String, dynamic>;
        if (msg['auth'] == manager.config.auth) {
          switch (msg['type']) {
            case 'list':
              webSocket.sink.add(json.encode({
                'type': 'list',
                "queryTask": manager.queryTask,
                ...manager.down.allTask
              }));
              manager.addTaskObserver(observer);
            case 'log':
              webSocket.sink.add(json.encode(
                  manager.outputEvent.buffer.map((e) => e.lines).toList()));
            default:
              {
                manager.parseCommandAndRun(msg['command']).then(
                    (r) => webSocket.sink.add(json.encode({'result': r})));
              }
          }
        } else {
          webSocket.sink.add(json.encode({'success': false}));
        }
      } catch (e) {
        manager.logger.e(e);
        webSocket.sink.add(json.encode({'success': false}));
      }
    })
      ..onDone(() => manager.removeTaskObserver(observer))
      ..onError((e) => manager.removeTaskObserver(observer));
  });
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
      .addMiddleware((innerHandler) => (req) {
            webSocket(req);
            return innerHandler(req);
          })
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
