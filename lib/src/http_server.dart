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
  HttpHeaders.contentTypeHeader: 'application/json',
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
          json.encode({'success': true, 'feature': _manager.config.aiTagPath}),
          headers: defaultRespHeader,
        ),
      )
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
        return _manager
            .findSugguestGallery(id.toInt())
            .then(
              (ids) =>
                  Response.ok(json.encode(ids), headers: defaultRespHeader),
            );
      })
      ..options('/suggest', _optionsOk)
      ..post('/fetchTag/<key>', _fetchTag)
      ..options('/fetchTag/<key>', _optionsOk)
      ..post('/proxy/<method>', _proxy)
      ..options(
        '/proxy/<method>',
        (req) => Response.ok(null, headers: defaultRespHeader),
      )
      ..get('/fetchImageData', _image)
      ..options(
        '/fetchImageData',
        (req) => Response.ok(
          null,
          headers: {
            ...defaultRespHeader,
            HttpHeaders.contentTypeHeader: 'application/octet-stream',
          },
        ),
      )
      ..post('/cancel', _cancel)
      ..options('/cancel', _optionsOk)
      ..post('/delete', _delete)
      ..post('/queryByImage', _searchByImage)
      ..options('/delete', _optionsOk)
      ..get('/ip', (req) {
        return NetworkInterface.list()
            .then(
              (value) => value.firstOrNull?.addresses
                  .where(
                    (element) =>
                        element.type == InternetAddressType.IPv6 &&
                        element.address.startsWith('2'),
                  )
                  .map((e) => e.address)
                  .toList(),
            )
            .then(
              (rep) =>
                  Response.ok(json.encode(rep), headers: defaultRespHeader),
            );
      })
      ..post('/excludes', (req) async {
        var succ = await _authToken(req);
        if (succ.key) {
          return Response.ok(
            json.encode(_manager.config.excludes),
            headers: defaultRespHeader,
          );
        }
        return Response.unauthorized('unauth');
      });
    localHitomi = createHitomi(_manager, true, 'http://127.0.0.1:7890');
  }

  Future<Response> _optionsOk(Request req) async {
    return Response.ok(
      null,
      headers: {
        ...defaultRespHeader,
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );
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
      _manager.logger.d('proxy $method task $task');
      switch (method!) {
        case 'fetchGallery':
          {
            var id = req.url.queryParameters['id'];
            var usePrefence = req.url.queryParameters['usePrefence'] == 'true';
            return localHitomi
                .fetchGallery(id, usePrefence: usePrefence)
                .then(
                  (value) => Response.ok(
                    json.encode(value),
                    headers: defaultRespHeader,
                  ),
                );
          }
        case 'search':
          {
            List<dynamic> tags = task.value['include'];
            List<dynamic>? exclude = task.value['excludes'];
            var querySort = task.value['sort'];
            SortEnum sort =
                SortEnum.values.firstWhereOrNull(
                  (element) => element.name == querySort,
                ) ??
                SortEnum.Default;
            return localHitomi
                .search(
                  _mapFromRequest(tags),
                  exclude: exclude != null
                      ? _mapFromRequest(exclude)
                      : _manager.config.excludes.fold(
                          <Label>[],
                          (acc, l) => acc
                            ..addAll(l.map((e) => fromString(e.type, e.name))),
                        ),
                  sort: sort,
                )
                .then(
                  (value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader,
                  ),
                );
          }
        case 'viewByTag':
          {
            final ip = req.headers['x-real-ip'] ?? '';
            _manager.logger.d('real ip $ip');
            List<dynamic> tags = task.value['tags'];
            var querySort = task.value['sort'];
            SortEnum? sort = SortEnum.values.firstWhereOrNull(
              (element) => element.name == querySort,
            );
            return localHitomi
                .viewByTag(
                  _mapFromRequest(tags).first,
                  page: task.value['page'] ?? 1,
                  sort: sort,
                )
                .then(
                  (value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader,
                  ),
                );
          }
        case 'findSimilar':
          {
            String string = task.value['gallery'];
            return localHitomi
                .findSimilarGalleryBySearch(Gallery.fromJson(string))
                .then(
                  (value) => Response.ok(
                    json.encode(value.toJson((p1) => p1)),
                    headers: defaultRespHeader,
                  ),
                );
          }
        default:
          {
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

  /// Fetches image data from the API based on query parameters.
  ///
  /// This method retrieves an image file from either a local or remote source
  /// using the provided image metadata and query parameters. It supports caching
  /// via ETag and handles conditional requests for improved performance.
  ///
  /// Parameters:
  ///   - [req]: The incoming Shelf Request object containing URL query parameters
  ///            and headers.
  ///
  /// Query Parameters:
  ///   - id: The gallery ID (required).
  ///   - hash: The image hash (required, must be 64 characters).
  ///   - name: The image filename (required).
  ///   - size: The thumbnail size (required).
  ///   - local: Boolean flag to indicate if the request is for a local source.
  ///   - translate: Boolean flag to indicate if translation is requested.
  ///   - lang: Language code for translation (defaults to 'ja').
  ///   - referer: Referrer URL for the request.
  ///
  /// Headers:
  ///   - If-None-Match: ETag header to support conditional requests.
  ///
  /// Returns:
  ///   A Future<Response> that completes with a Shelf Response containing
  ///   the image data and appropriate headers, or an error response if the
  ///   request parameters are invalid.
  Future<Response> _image(Request req) async {
    var hash = req.url.queryParameters['hash'];
    var name = req.url.queryParameters['name'];
    var size = req.url.queryParameters['size'];
    var local = req.url.queryParameters['local'] == 'true';
    if ((hash?.length ?? 0) != 64 || size == null || name == null) {
      _manager.logger.d(' $hash $name $size $local');
      return Response.badRequest();
    }
    var before = req.headers['If-None-Match'];
    if (before != null && before == hash) {
      return Response.notModified();
    }
    return (local ? localHitomi : _manager.getApiDirect(HitomiType.Remote))
        .fetchImageData(
          Image(hash: hash!, hasavif: 0, width: 0, name: name, height: 0),
          refererUrl: req.url.queryParameters['referer'] ?? hitomiUrl,
          size: ThumbnaiSize.values.firstWhere(
            (element) => element.name == size,
          ),
        )
        .fold(<int>[], (acc, l) => acc..addAll(l))
        .then(
          (value) => Response.ok(
            Stream.value(value),
            headers: {
              ...defaultRespHeader,
              HttpHeaders.cacheControlHeader: 'public, max-age=259200',
              HttpHeaders.etagHeader: hash,
              HttpHeaders.contentTypeHeader:
                  'image/${extension(name).substring(1)}',
              HttpHeaders.contentLengthHeader: value.length.toString(),
            },
          ),
        );
  }

  /// Translates labels from the request body using the task manager.
  ///
  /// This method handles a POST request to translate labels. It expects an
  /// authentication token in the request body and processes the 'tags' field
  /// to convert them into translated labels. Only labels that are not of type
  /// QueryText are included in the translation process.
  ///
  /// Parameters:
  ///   - [req]: The incoming Shelf Request object containing the body with
  ///            authentication token and tags to translate.
  ///
  /// Request Body Format:
  ///   A JSON object with:
  ///   - auth: Authentication token for authorization.
  ///   - tags: List of tag objects (or strings) to be translated.
  ///
  /// Returns:
  ///   A Future<Response> that completes with a Shelf Response containing
  ///   the translated labels in JSON format if authentication is successful,
  ///   or an unauthorized response otherwise.
  Future<Response> _translate(Request req) async {
    final task = await _authToken(req);
    if (task.key) {
      Set<Label> keys = (task.value['tags'] as List<dynamic>)
          .map(
            (e) =>
                (e is Map<String, dynamic>) ? e : (json.decode(e.toString())),
          )
          .map((e) => fromString(e['type'], e['name']))
          .where((element) => element.runtimeType != QueryText)
          .toSet();

      return _manager
          .translateLabel(keys.toList())
          .then((value) => value.values.toList())
          .then(
            (value) =>
                Response.ok(json.encode(value), headers: defaultRespHeader),
          );
    }
    return Response.unauthorized('unauth');
  }

  /// Adds a new task to the task manager after authentication and IP validation.
  ///
  /// This method handles a POST request to add a new task. It verifies the
  /// authentication token and checks if the request is coming from a local or
  /// LAN IP address. If both conditions are met, it parses the task command
  /// and executes it using the task manager.
  ///
  /// Parameters:
  ///   - [req]: The incoming Shelf Request object containing the body with
  ///            authentication token and task details.
  ///
  /// Request Body Format:
  ///   A JSON object with:
  ///   - auth: Authentication token for authorization.
  ///   - task: The command or task to be executed.
  ///
  /// Headers:
  ///   - x-real-ip: The real IP address of the client making the request.
  ///
  /// Returns:
  ///   A Future<Response> that completes with a Shelf Response indicating
  ///   success if authentication and IP validation pass, or an unauthorized
  ///   response otherwise.
  Future<Response> _addTask(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.key && _isLocalOrLAN(InternetAddress(ip))) {
      _manager.parseCommandAndRun(task.value['task']);
      return Response.ok(
        json.encode({'success': true}),
        headers: defaultRespHeader,
      );
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _checkId(Request req) async {
    final task = await _authToken(req);
    if (task.key) {
      List<dynamic> ids = task.value['ids'];
      return _manager
          .checkExistsId(ids)
          .then((value) => {'success': true, 'value': value})
          .then(
            (value) =>
                Response.ok(json.encode(value), headers: defaultRespHeader),
          );
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
      return localHitomi
          .fetchSuggestions(key)
          .then(
            (value) =>
                Response.ok(json.encode(value), headers: defaultRespHeader),
          );
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _cancel(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.key && _isLocalOrLAN(InternetAddress(ip))) {
      return _manager
          .parseCommandAndRun('-p ${task.value['id']}')
          .then(
            (value) => Response.ok(
              json.encode({'success': value}),
              headers: defaultRespHeader,
            ),
          );
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _delete(Request req) async {
    final task = await _authToken(req);
    final ip = req.headers['x-real-ip'] ?? '';
    _manager.logger.d('real ip $ip');
    if (task.key && _isLocalOrLAN(InternetAddress(ip))) {
      return _manager
          .parseCommandAndRun('-d ${task.value['id']}')
          .then(
            (value) => Response.ok(
              json.encode({'success': value}),
              headers: defaultRespHeader,
            ),
          );
    }
    return Response.unauthorized('unauth');
  }

  bool _isLocalOrLAN(InternetAddress address) {
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
    _manager.logger.d(
      'real ip $ip mark ${task.value['mark']} content ${task.value['content'].length}',
    );
    if (task.key && _isLocalOrLAN(InternetAddress(ip))) {
      int mark = task.value['mark'];
      bool returnValue = task.value['returnValue'] ?? false;
      List<dynamic> content = task.value['content'];
      if (mark == admarkMask) {
        return _manager
            .addAdMark(content.map((e) => e as String).toList())
            .then(
              (value) => Response.ok(
                json.encode({
                  'success': value,
                  'content': returnValue
                      ? _manager.adImage.where((s) => !content.contains(s))
                      : [],
                }),
                headers: defaultRespHeader,
              ),
            );
      } else if ([readHistoryMask, bookMarkMask, lateReadMark].contains(mark)) {
        var list = content.map((e) => e as Map<String, dynamic>).toList();
        return _manager
            .manageUserLog(list, mark)
            .then(
              (v) async => returnValue
                  ? await _manager.helper
                        .querySql(
                          'select id,value,type,content,date from UserLog where type = $mark',
                        )
                        .then(
                          (set) => set
                              .where(
                                (r) => !list.any(
                                  (m) =>
                                      m['id'] == r['id'] &&
                                      m['value'] == r['value'],
                                ),
                              )
                              .map((r) => r)
                              .toList(),
                        )
                  : [],
            )
            .then(
              (value) => Response.ok(
                json.encode({'success': true, 'content': value}),
                headers: defaultRespHeader,
              ),
            );
      }
      return Response.badRequest();
    }
    return Response.unauthorized('Unauthorized');
  }

  Future<Response> _searchByImage(Request req) async {
    var limit = req.params['limit'] ?? '5';
    var file = await req.read().fold(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
    return _manager
        .searchByImage(file, limit: limit.toInt())
        .then(
          (result) =>
              Response.ok(json.encode(result), headers: defaultRespHeader),
        );
  }
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
                webSocket.sink.add(
                  json.encode({
                    'type': 'list',
                    "queryTask": manager.queryTask,
                    ...manager.down.allTask,
                  }),
                );
                manager.addTaskObserver(observer);
              case 'log':
                webSocket.sink.add(
                  json.encode(
                    manager.outputEvent.buffer.map((e) => e.lines).toList(),
                  ),
                );
              default:
                {
                  manager
                      .parseCommandAndRun(msg['command'])
                      .then(
                        (r) => webSocket.sink.add(json.encode({'result': r})),
                      );
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
      .addMiddleware(
        logRequests(
          logger: (message, isError) =>
              isError ? manager.logger.e(message) : manager.logger.d(message),
        ),
      )
      .addMiddleware(
        (innerHandler) => (req) {
          return Future.sync(() => innerHandler(req)).then(
            (value) => value.statusCode == 404 && staticHandle != null
                ? staticHandle(req)
                : value,
          );
        },
      )
      .addMiddleware(
        (innerHandler) => (req) {
          webSocket(req);
          return innerHandler(req);
        },
      )
      .addHandler(_TaskWarp(manager).router);
  // For running in containers, we respect the PORT environment variable.
  final socketPort = int.parse(Platform.environment['PORT'] ?? '7890');
  final servers = await serve(
    handler,
    InternetAddress.anyIPv6,
    socketPort,
    poweredByHeader: 'ayaka',
  );
  servers.autoCompress = true;
  manager.logger.i(
    'Server run on http://${servers.address.address}:${servers.port}',
  );
  return servers;
}
