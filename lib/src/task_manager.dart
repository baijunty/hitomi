import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dcache/dcache.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/group.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/downloader.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:logger/logger.dart';
import '../gallery/language.dart';
import 'dir_scanner.dart';
import 'gallery_util.dart';
import 'hitomi_impl.dart';
import 'multi_paltform.dart';

@pragma('vm:entry-point')
Future<MapEntry<int, List<int>?>> _compressRunner(String imagePath) async {
  return File(imagePath)
      .readAsBytes()
      .then((value) => resizeThumbImage(value, 256).then((v) async {
            return MapEntry(
                await imageHash(v ?? value)
                    .catchError((e) => 0, test: (error) => true),
                v?.toList(growable: false));
          }))
      .catchError((e) => MapEntry(0, null), test: (error) => true);
}

class TaskManager {
  final UserConfig config;
  late ArgParser _parser;
  late SqliteHelper helper;
  late DownLoader _downLoader;
  late Hitomi _api;
  late Hitomi _localApi;
  late Hitomi _webHitomi;
  late Logger logger;
  final Dio dio = Dio();
  final _tasks = <Label>{};
  final Set<MapEntry<int, String>> _adImage = {};
  final _storage = InMemoryStorage<Label, Map<String, dynamic>>(1024);
  late SimpleCache<Label, Map<String, dynamic>> _cache =
      SimpleCache<Label, Map<String, dynamic>>(storage: _storage);
  final _reg = RegExp(r'!?\[(?<name>.*?)\]\(#*\s*\"?(?<url>\S+?)\"?\)');
  late IsolateManager<MapEntry<int, List<int>?>, String> _manager;
  DownLoader get down => _downLoader;
  Hitomi getApiDirect({bool local = false}) {
    return local ? _localApi : _api;
  }

  Hitomi getApiFromProxy(String auth, String proxyAddr) {
    return _webHitomi;
  }

  TaskManager(this.config) {
    Level level;
    switch (config.logLevel) {
      case 'debug':
        level = Level.debug;
      case 'none':
        level = Level.off;
      case 'warn':
        level = Level.warning;
      case 'error':
        level = Level.error;
      case 'trace':
        level = Level.trace;
      default:
        level = Level.fatal;
    }
    LogOutput outputEvent;
    if (config.logOutput.isNotEmpty) {
      outputEvent = FileOutput(file: File(config.logOutput));
    } else {
      outputEvent = ConsoleOutput();
    }
    logger = Logger(
        filter: ProductionFilter(),
        output: outputEvent,
        level: level,
        printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 10,
            printEmojis: false,
            printTime: false,
            noBoxingByDefault: true));
    _manager = IsolateManager<MapEntry<int, List<int>?>, String>.create(
        _compressRunner,
        concurrent: config.maxTasks);
    helper = SqliteHelper(config.output, logger: logger);
    dio.httpClientAdapter = crateHttpClientAdapter(config.proxy);
    _api = createHitomi(this, false, config.remoteHttp);
    _localApi = createHitomi(this, true, config.remoteHttp);
    _webHitomi = WebHitomi(dio, true, config.auth, config.remoteHttp);
    _downLoader = DownLoader(
        config: config,
        api: _api,
        helper: helper,
        manager: this._manager,
        logger: logger,
        dio: dio);
    _parser = ArgParser()
      ..addFlag('fix')
      ..addFlag('fixDb')
      ..addFlag('fixDup')
      ..addFlag('update', abbr: 'u')
      ..addFlag('continue', abbr: 'c')
      ..addOption('pause', abbr: 'p')
      ..addOption('delete', abbr: 'd')
      ..addOption('artist', abbr: 'a')
      ..addOption('admark')
      ..addOption('group', abbr: 'g')
      ..addFlag('list', abbr: 'l')
      ..addMultiOption('tags', abbr: 't');
    helper
        .querySql('select * from UserLog where type=?', [1 << 17])
        .then((value) => value.map((element) =>
            MapEntry<int, String>(element['mark'], element['content'])))
        .then((value) {
          logger.d('load ${value.length} ads');
          _adImage.addAll(value);
        });
  }

  String _takeTranslateText(String input) {
    var matches = _reg.allMatches(input);
    if (matches.isNotEmpty) {
      int start = 0;
      var sb = StringBuffer();
      for (var element in matches) {
        sb.write(input.substring(start, element.start));
        start = element.end;
      }
      sb.write(input.substring(start));
      return sb.toString();
    }
    return input;
  }

  Future<List<List<dynamic>>> _fetchTagsFromNet({CancelToken? token}) async {
    // var rows = _db.select(
    //     'select intro from Tags where type=? by intro desc', ['author']);
    // Map<String, dynamic> author =
    //     (data['head'] as Map<String, dynamic>)['author'];
    final Map<String, dynamic> data = await dio
        .httpInvoke<String>(
            'https://github.com/EhTagTranslation/Database/releases/latest/download/db.raw.json',
            token: token)
        .then((value) => json.decode(value));
    if (data['data'] is List<dynamic>) {
      var rows = data['data'] as List<dynamic>;
      var params = rows
          .map((e) => e as Map<String, dynamic>)
          .map((e) => MapEntry(
              e['namespace'] as String, e['data'] as Map<String, dynamic>))
          .fold<List<List<dynamic>>>([], (st, e) {
        final key = ['mixed', 'other', 'cosplayer', 'temp'].contains(e.key)
            ? 'tag'
            : e.key.replaceAll('reclass', 'type');
        e.value.entries.fold<List<List<dynamic>>>(st, (previousValue, element) {
          final name = element.key;
          final value = element.value as Map<String, dynamic>;
          return previousValue
            ..add([
              null,
              key,
              name,
              _takeTranslateText(value['name']),
              value['intro'],
              value['links'],
              null
            ]);
        });
        return st;
      });
      return params;
    }
    return [];
  }

  Future<List<int>> checkExistsId(int id) async {
    var row =
        await helper.queryGalleryById(id).then((value) => value.firstOrNull);
    if (row != null) {
      return [id];
    }
    return _api.fetchGallery(id, usePrefence: false).then((value) =>
        value.createDir(config.output, createDir: false).existsSync()
            ? readGalleryFromPath(
                    value.createDir(config.output, createDir: false).path)
                .then((value) => [value.id])
            : findDuplicateGalleryIds(value, helper, _api, logger: logger));
  }

  Future<Map<Label, Map<String, dynamic>>> collectedInfo(List<Label> keys) {
    return keys
        .where((element) => !_cache.containsKey(element))
        .groupListsBy((element) => element.localSqlType)
        .entries
        .asStream()
        .asyncMap((entry) {
      return helper
          .selectSqlMultiResultAsync(
              'select count(1) as count,date as date from Gallery where json_value_contains(${entry.key},?,?)=1',
              entry.value
                  .where((element) => element.runtimeType != TypeLabel)
                  .map((e) => [e.name, e.type])
                  .toList())
          .then((value) {
        return value.entries.fold(<Label, Map<String, dynamic>>{},
            (previousValue, element) {
          final row = element.value.firstOrNull;
          if (row != null && row['date'] != null) {
            previousValue[fromString(element.key[1], element.key[0])] = {
              'count': row['count'],
              'date':
                  DateTime.fromMillisecondsSinceEpoch(row['date']).toString()
            };
          }
          return previousValue;
        });
      });
    }).fold(<Label, Map<String, dynamic>>{},
            (previous, element) => previous..addAll(element));
  }

  Future<Map<Label, Map<String, dynamic>>> translateLabel(
      List<Label> keys) async {
    var count = await collectedInfo(keys);
    var missed =
        keys.groupListsBy((element) => _cache[element] != null)[false] ?? [];
    if (missed.isNotEmpty) {
      var result = await helper.selectSqlMultiResultAsync(
          'select translate,intro,links from Tags where type=? and name=?',
          missed.map((e) => e.params).toList());
      missed.fold(_cache, (previousValue, element) {
        final v = result.entries
            .firstWhereOrNull((e) => e.key.equals(element.params))
            ?.value
            .firstOrNull;
        if (v != null) {
          previousValue[element] = {...v, ...element.toMap()};
        } else {
          previousValue[element] = {
            'translate': element.name,
            ...element.toMap()
          };
        }
        previousValue[element]!.addAll(count[element] ?? {});
        return previousValue;
      });
    }
    final r =
        keys.fold(<Label, Map<String, dynamic>>{}, (previousValue, element) {
      var translate =
          _cache[element] ?? {'translate': element.name, ...element.toMap()};
      element.translate = translate;
      return previousValue..[element] = translate;
    });
    return r;
  }

  List<String> _parseArgs(String cmd) {
    var words = cmd.split(blankExp);
    final args = <String>[];
    bool markCollct = false;
    final markWords = [];
    for (var content in words) {
      if ((content.startsWith("'") ||
          content.startsWith("\"") && !markCollct)) {
        markCollct = true;
        markWords.clear();
        content = content.substring(1, content.length);
      }
      if ((content.endsWith("'") || content.endsWith("\"")) && markCollct) {
        markWords.add(content.substring(0, content.length - 1));
        content = markWords.join(' ');
        markCollct = false;
      }
      if (markCollct) {
        markWords.add(content);
      } else {
        args.add(content);
      }
    }
    if (markCollct) {
      args.clear();
    }
    return args;
  }

  Future<int> _fixGallerys() async {
    final count = await DirScanner(config, helper, _downLoader, _manager)
        .listDirs()
        .filterNonNull()
        .where((event) {
          var b = event.gallery != null;
          if (!b) {
            logger.w('delete empty floder ${event.dir}');
            event.dir.deleteSync(recursive: true);
          }
          return b;
        })
        .fold(
            <String, List<HitomiDir>>{},
            (previous, element) => previous
              ..[element.gallery!.id.toString()] =
                  ((previous[element.gallery!.id.toString()] ?? [])
                    ..add(element)))
        .then((value) => value.values.toList())
        .asStream()
        .expand((element) => element)
        .slices(5)
        .asyncMap((list) {
          return Future.wait(list.map((event) {
            if (event.length > 1) {
              event
                  .sublist(1)
                  .where((element) => element.dir.existsSync())
                  .forEach((e) {
                logger.d('delete duplication ${e.gallery?.id} with ${e.dir}');
                e.dir.deleteSync(recursive: true);
              });
            }
            return event.first.fixGallery();
          })).then((value) => value.length);
        })
        .fold(0, (previous, element) => previous + element);
    logger.d("scan finishd ${count}");
    return count;
  }

  Future<Stream<Gallery>> remainTask() {
    return helper
        .querySqlByCursor('select id from Tasks where completed = ?', [0]).then(
            (value) => value.asyncMap((event) async {
                  try {
                    var r = await _api.fetchGallery(event['id']);
                    if (r.id.toString() != event['id'].toString()) {
                      logger.d(' $event update to ${r.id}');
                      await helper.removeTask(event['id'], withGaller: true);
                    }
                    return r;
                  } catch (e) {
                    logger.d('fetchGallery error $e');
                    await helper.removeTask(event['id'], withGaller: true);
                  }
                  return null;
                }).filterNonNull());
  }

  void removeAdImages(Gallery gallery) {
    if (gallery.language == 'chinese' ||
        gallery.tags?.any((element) => element.name == 'extraneous ads') ==
            true) {
      gallery.files.removeWhere(
          (image) => _adImage.any((element) => element.value == image.hash));
    }
  }

  Future<dynamic> parseCommandAndRun(String cmd) async {
    bool hasError = false;
    var args = _parseArgs(cmd);
    logger.w('args $args');
    if (args.isEmpty) {
      return false;
    }
    try {
      final result = _parser.parse(args);
      if (numberExp.hasMatch(cmd)) {
        String id = cmd;
        hasError = !numberExp.hasMatch(id);
        if (!hasError) {
          return await _api
              .fetchGallery(id)
              .then((value) => _downLoader.addTask(value))
              .then((value) => true)
              .catchError((e) {
            logger.e('add task $e');
            return false;
          }, test: (error) => true);
        }
      } else if (result.wasParsed('artist')) {
        String? artist = result['artist'];
        hasError = artist == null || artist.isEmpty;
        if (!hasError && _tasks.every((value) => value.name != artist)) {
          final label = Artist(artist: artist);
          _tasks.add(label);
          return _downLoader.downLoadByTag(<Label>[
            label,
            ...config.languages.map((e) => Language(name: e)),
            TypeLabel('doujinshi'),
            TypeLabel('manga')
          ], MapEntry('artist', artist), CancelToken(),
              onFinish: (success) async {
            _tasks.remove(label);
            _storage.remove(label);
            await translateLabel([label]);
          });
        }
      } else if (result.wasParsed('group')) {
        String? group = result['group'];
        hasError = group == null || group.isEmpty;
        if (!hasError && _tasks.every((value) => value.name != group)) {
          final label = Group(group: group);
          _tasks.add(label);
          return _downLoader.downLoadByTag(<Label>[
            label,
            ...config.languages.map((e) => Language(name: e)),
            TypeLabel('doujinshi'),
            TypeLabel('manga')
          ], MapEntry('groupes', group), CancelToken(),
              onFinish: (success) async {
            _tasks.remove(label);
            _storage.remove(label);
            await translateLabel([label]);
          });
        }
      } else if (result.wasParsed('tags')) {
        List<Label> tags = result["tags"]
            .map((e) => e.split(':'))
            .where((value) => value.length >= 2)
            .map((e) => fromString(e[0], e[1]))
            .toList();
        _tasks.addAll(tags);
        return _downLoader.downLoadByTag(
            tags..addAll(config.languages.map((e) => Language(name: e))),
            MapEntry(tags.first.type, tags.first.name),
            CancelToken(),
            onFinish: (success) => _tasks.removeAll(tags));
      } else if (result.wasParsed('delete')) {
        String deleteId = result["delete"];
        logger.d('delete ${deleteId}');
        if (numberExp.hasMatch(deleteId)) {
          return _downLoader.deleteById(int.parse(deleteId));
        }
        return false;
      } else if (result.wasParsed('pause')) {
        String id = result["pause"];
        logger.d('pause ${id}');
        if (numberExp.hasMatch(id)) {
          return _downLoader.cancelById(int.parse(id));
        }
        return false;
      } else if (result.wasParsed('admark')) {
        String hash = result["admark"];
        logger.d('pause ${hash}');
        if (hash.length == 64) {
          return _api
              .fetchImageData(Image(
                  hash: hash,
                  hasavif: 0,
                  width: 0,
                  haswebp: 0,
                  name: 'hash.jpg',
                  height: 0))
              .then((value) => imageHash(Uint8List.fromList(value)))
              .then((value) {
            _adImage.add(MapEntry(value, hash));
            logger.d('now hash ${_adImage.length} admrks');
            return helper.insertUserLog(hash.hashCode.abs() * -1, 1 << 17,
                mark: value, content: hash);
          });
        }
        return false;
      } else if (result['fixDb']) {
        final count = await DirScanner(config, helper, _downLoader, _manager)
            .fixMissDbRow();
        logger.d("database fix ${count}");
      } else if (result['fixDup']) {
        final count = await DirScanner(config, helper, _downLoader, _manager)
            .removeDupGallery();
        logger.d("database fix ${count}");
        return count;
      } else if (result['fix']) {
        return _fixGallerys().then((value) => value > 0);
      } else if (result['update']) {
        return _fetchTagsFromNet()
            .then((value) => helper.updateTagTable(value));
      } else if (result['continue']) {
        return remainTask().then((value) =>
            value.asyncMap((event) => _downLoader.addTask(event)).length);
      } else if (result['list']) {
        return <String, dynamic>{
          "queryTask": _tasks
              .map((e) => {'href': '/${e.urlEncode()}-all.html', ...e.toMap()})
              .toList(),
          "pendingTask": _downLoader.pendingTask
              .map((t) => {
                    'href': t.gallery.galleryurl!,
                    'name': t.gallery.dirName,
                    'gallery': t.gallery
                  })
              .toList(),
          "runningTask": _downLoader.runningTask
        };
      }
      if (hasError) {
        logger.e('$cmd error with ${args}');
      }
      return !hasError;
    } catch (e) {
      logger.e(e);
      return false;
    }
  }
}
