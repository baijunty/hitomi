import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dcache/dcache.dart';
import 'package:dio/dio.dart' show Dio;
import 'package:dio/io.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/tag.dart';
import 'package:hitomi/src/task_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tuple/tuple.dart';

class _TaskWarp {
  final TaskManager _manager;
  final _cache = SimpleCache(storage: InMemoryStorage(1024));
  final _dio = Dio();
  final Router router = Router();
  _TaskWarp(this._manager) {
    router.get('/', (req) => Response.ok('ok'));
    router.post('/translate', _translate);
    router.post('/addTask', _addTask);
    router.post('/listTask', _listTask);
    _dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      return HttpClient()
        ..connectionTimeout = Duration(seconds: 30)
        ..findProxy = (u) => (_manager.config.proxy.isEmpty)
            ? 'DIRECT'
            : 'PROXY ${_manager.config.proxy}';
    });
  }

  Future<Tuple2<bool, Map<String, dynamic>>> _authToken(Request req) async {
    Map<String, dynamic> body = json.decode(await req.readAsString());
    return Tuple2(body['auth'] == _manager.config.auth, body);
  }

  Future<Response> _translate(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      List<Lable> keys = (task.item2['tags'] as List<dynamic>)
          .map((e) => Tag.fromMap(e as Map<String, dynamic>))
          .toList();
      var missed =
          keys.groupListsBy((element) => _cache[element] != null)[false] ?? [];
      if (missed.isNotEmpty) {
        final params = missed.map((e) => e.params).toList();
        var result = await _manager.helper.selectSqlMultiResultAsync(
            'select translate from Tags where type=? and name=?', params);
        missed.fold(_cache, (previousValue, element) {
          final v = result.entries
              .firstWhereOrNull((e) => e.key.equals(element.params))
              ?.value
              .firstOrNull?['translate'];
          previousValue[element] = v;
          return previousValue;
        });
      }
      missed =
          keys.groupListsBy((element) => _cache[element] != null)[false] ?? [];
      if (missed.isNotEmpty) {
        await Stream.fromIterable(missed).asyncMap((event) async {
          await _dio
              .getUri<List<dynamic>>(Uri.parse(
                  'https://baijunty.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=zh&q=${event.name}'))
              .then((value) {
            final v = value.data![0] as String;
            print('from net $event return $v ');
            _cache[event] = v;
            return v;
          });
        }).toList();
      }
      var r = keys.fold(<String, dynamic>{},
          (previous, element) => previous..[element.name] = _cache[element]);
      r['success'] = true;
      return Response.ok(json.encode(r),
          headers: {HttpHeaders.contentTypeHeader: 'application/json'});
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _addTask(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      bool r = await _manager.parseCommandAndRun(task.item2['task']);
      return Response.ok("{success:$r}",
          headers: {HttpHeaders.contentTypeHeader: 'application/json'});
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _listTask(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      var r = await _manager.parseCommandAndRun('-l');
      return Response.ok('{"success":true,"content":${json.encode(r)}}',
          headers: {HttpHeaders.contentTypeHeader: 'application/json'});
    }
    return Response.unauthorized('unauth');
  }
}

void run_server(TaskManager manager) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(_TaskWarp(manager).router);
  // For running in containers, we respect the PORT environment variable.
  final socketPort = int.parse(Platform.environment['PORT'] ?? '7890');
  final servers = await serve(handler, InternetAddress.anyIPv6, socketPort);
  servers.autoCompress = true;
  print('Server run on http://${servers.address.address}:${servers.port}');
}
