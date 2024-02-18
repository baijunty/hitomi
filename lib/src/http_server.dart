import 'dart:convert';
import 'dart:io';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/src/task_manager.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tuple/tuple.dart';

class _TaskWarp {
  final TaskManager _manager;
  final Router router = Router();
  _TaskWarp(this._manager) {
    router.get('/', (req) => Response.ok('ok'));
    router.post('/translate', _translate);
    router.post('/addTask', _addTask);
    router.post('/listTask', _listTask);
    router.post('/excludes', (req) async {
      var succ = await _authToken(req);
      if (succ.item1) {
        return Response.ok(json.encode(_manager.config.excludes),
            headers: {HttpHeaders.contentTypeHeader: 'application/json'});
      }
      return Response.unauthorized('unauth');
    });
  }

  Future<Tuple2<bool, Map<String, dynamic>>> _authToken(Request req) async {
    var posted = await req.readAsString();
    if (posted.isNotEmpty) {
      Map<String, dynamic> body = json.decode(posted);
      return Tuple2(body['auth'] == _manager.config.auth, body);
    }
    return Tuple2(false, Map());
  }

  Future<Response> _translate(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      List<Lable> keys = (task.item2['tags'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => fromString(e['type'], e['name']))
          .toList();
      final r = await _manager.downLoader.translateLabel(keys).then((value) =>
          value.fold(
              <String, dynamic>{},
              (previousValue, element) =>
                  previousValue..[element.name] = element.translate));
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
      .addMiddleware(logRequests(
          logger: (message, isError) =>
              isError ? manager.logger.e(message) : manager.logger.d(message)))
      .addHandler(_TaskWarp(manager).router);
  // For running in containers, we respect the PORT environment variable.
  final socketPort = int.parse(Platform.environment['PORT'] ?? '7890');
  final servers = await serve(handler, InternetAddress.anyIPv6, socketPort);
  servers.autoCompress = true;
  manager.logger
      .i('Server run on http://${servers.address.address}:${servers.port}');
}
