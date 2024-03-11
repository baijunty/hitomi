import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dcache/dcache.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:path/path.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tuple/tuple.dart';

class _TaskWarp {
  final TaskManager _manager;
  final _cache = SimpleCache<Label, MapEntry<int, String>?>(
      storage: InMemoryStorage(1024));
  final Router router = Router();
  _TaskWarp(this._manager) {
    router.get('/', (req) => Response.ok('ok'));
    router.post('/translate', _translate);
    router.post('/addTask', _addTask);
    router.post('/listTask', _listTask);
    router.get('/thumb/<gid>/<hash>', _thumb);
    router.get('/image/<gid>/<hash>', _image);
    router.post('/excludes', (req) async {
      var succ = await _authToken(req);
      if (succ.item1) {
        return Response.ok(json.encode(_manager.config.excludes.keys.toList()),
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

  Future<Response> _loadImageInner<T>(
      Request req,
      Future<MapEntry<String, T>?> Function(String id, String hash)
          fetch) async {
    var id = req.params['gid'];
    var hash = req.params['hash'];
    _manager.logger.d('req $id $hash');
    if (id == null || hash == null || hash.length != 64) {
      return Response.badRequest();
    }
    var before = req.headers['If-None-Match'];
    if (before != null && before == hash) {
      return Response.notModified();
    }
    var data = await fetch(id, hash);
    if (data != null) {
      var fileName = data.key;
      return Response.ok(data.value, headers: {
        HttpHeaders.contentTypeHeader:
            'image/${extension(fileName).substring(1)}',
        HttpHeaders.cacheControlHeader: 'public, max-age=259200',
        HttpHeaders.etagHeader: hash,
      });
    }
    return Response.notFound(null);
  }

  Future<Response> _thumb(Request req) async {
    var fetch = (id, hash) => _manager.helper
        .querySqlByCursor(
            'select gf.thumb,gf.name from GalleryFile gf where gid=? and hash=?',
            [
              id,
              hash
            ])
        .asyncMap((event) =>
            MapEntry<String, List<int>>(event['name'], event['thumb']))
        .firstOrNull;
    return _loadImageInner<List<int>>(req, fetch);
  }

  Future<Response> _image(Request req) async {
    var fetch = (id, hash) => _manager.helper.querySqlByCursor(
            'select gf.name,g.path from Gallery g left join GalleryFile gf on g.id=gf.gid where gf.gid=? and gf.hash=?',
            [id, hash]).asyncMap((event) async {
          String fileName = event['name'];
          String path = join(_manager.config.output, event['path'], fileName);
          return MapEntry<String, Stream<List<int>>>(
              fileName, File(path).openRead());
        }).firstOrNull;
    return _loadImageInner<Stream<List<int>>>(req, fetch);
  }

  Future<Response> _translate(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      Set<Label> keys = (task.item2['tags'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => fromString(e['type'], e['name']))
          .where((element) => element.runtimeType != QueryText)
          .toSet();
      ;
      final r = await _collectionTags(keys.toList());
      return Response.ok(json.encode(r),
          headers: {HttpHeaders.contentTypeHeader: 'application/json'});
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
              entry.value.map((e) => [e.name, e.type]).toList())
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
    final r = await _manager.downLoader
        .translateLabel(keys)
        .then((value) => value.entries.map((entry) {
              var key = entry.key;
              var value = entry.value;
              final cache = _cache[key];
              if (cache != null) {
                value['count'] = cache.key;
                value['date'] = cache.value;
              }
              value['type'] = key.type;
              value['name'] = key.name;
              return value;
            }).toList());
    return r;
  }

  Future<Response> _addTask(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      _manager.parseCommandAndRun(task.item2['task']);
      return Response.ok("{success:true}",
          headers: {HttpHeaders.contentTypeHeader: 'application/json'});
    }
    return Response.unauthorized('unauth');
  }

  Future<Response> _listTask(Request req) async {
    final task = await _authToken(req);
    if (task.item1) {
      Map<String, dynamic> r = await _manager.parseCommandAndRun('-l');
      r['success'] = true;
      return Response.ok(json.encode(r),
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
