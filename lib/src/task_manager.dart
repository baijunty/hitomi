import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:dio/dio.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/group.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/downloader.dart';
import 'package:hitomi/src/gallery_util.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';
import '../gallery/language.dart';
import 'dhash.dart';
import 'dir_scanner.dart';
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
  late DownLoader downLoader;
  late Hitomi _api;
  late Hitomi _localApi;
  late Logger logger;
  final Dio dio = Dio();
  final _tasks = <Label>{};
  final reg = RegExp(r'!?\[(?<name>.*?)\]\(#*\s*\"?(?<url>\S+?)\"?\)');
  late IsolateManager<MapEntry<int, List<int>?>, String> manager;

  Hitomi getApi({bool local = false}) {
    return local ? _localApi : _api;
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
    manager = IsolateManager<MapEntry<int, List<int>?>, String>.create(
        _compressRunner,
        concurrent: config.maxTasks);
    helper = SqliteHelper(config.output, logger: logger);
    dio.httpClientAdapter = crateHttpClientAdapter(config.proxy);
    _api = createHitomi(this, false, config.remoteHttp);
    _localApi = createHitomi(this, true, config.remoteHttp);
    downLoader = DownLoader(
        config: config,
        api: _api,
        helper: helper,
        manager: this.manager,
        logger: logger,
        dio: dio);
    _parser = ArgParser()
      ..addFlag('fix')
      ..addFlag('fixDb')
      ..addFlag('fixDup')
      ..addFlag('update', abbr: 'u')
      ..addFlag('continue', abbr: 'c')
      ..addOption('artist', abbr: 'a')
      ..addOption('group', abbr: 'g')
      ..addFlag('list', abbr: 'l')
      ..addMultiOption('delete', abbr: 'd')
      ..addMultiOption('tags', abbr: 't');
  }

  void cancel() {
    downLoader.cancelAll();
  }

  String takeTranslateText(String input) {
    var matches = reg.allMatches(input);
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

  Future<List<List<dynamic>>> fetchTagsFromNet({CancelToken? token}) async {
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
              takeTranslateText(value['name']),
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

  Future<int> deleteByLabel(List<Label> labels) async {
    return labels.asStream().asyncMap((element) async {
      late ResultSet galleryQuery;
      switch (element) {
        case QueryText():
          {
            downLoader[element.name]?.cancel();
            downLoader.removeTask(element.name);
            galleryQuery = await helper.queryGalleryById(element.name);
          }
        default:
          {
            downLoader.cancelByTag(element);
            galleryQuery =
                await helper.queryGalleryByLabel(element.localSqlType, element);
          }
      }
      await galleryQuery
          .asStream()
          .asyncMap((event) =>
              readGalleryFromPath(join(config.output, event['path'])))
          .map((event) => HitomiDir(
              event.createDir(config.output), downLoader, event, manager))
          .asyncMap((element) {
            element.deleteGallery();
          })
          .length
          .catchError((e) {
            logger.e('del form key ${element.name} faild $e');
            return 0;
          }, test: (error) => true);
    }).length;
  }

  Future<int> fixGallerys() async {
    final count = await DirScanner(config, helper, downLoader, manager)
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

  Future<int> runRemainTask() async {
    var tasks =
        await helper.querySql('select id from Tasks where completed = ?', [0]);
    logger.d("left task ${tasks.length}");
    return await Stream.fromIterable(tasks)
        .asyncMap((event) async {
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
        })
        .filterNonNull()
        .asyncMap((value) async {
          var b =
              await findDuplicateGalleryIds(value, helper, _api, logger: logger)
                  .then((value) => value.isEmpty);
          if (!b) {
            logger.d('delete task $value');
            value.createDir(config.output).delete(recursive: true);
            await helper.removeTask(value.id, withGaller: true);
          } else {
            return value;
          }
        })
        .filterNonNull()
        .asyncMap((element) {
          downLoader.addTask(element);
        })
        .length;
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
          await _api
              .fetchGallery(id)
              .then((value) => downLoader.addTask(value))
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
          return await downLoader.downLoadByTag(<Label>[
            label,
            ...config.languages.map((e) => Language(name: e)),
            TypeLabel('doujinshi'),
            TypeLabel('manga')
          ], MapEntry('artist', artist), CancelToken(),
              onFinish: (success) => _tasks.remove(label));
        }
      } else if (result.wasParsed('group')) {
        String? group = result['group'];
        hasError = group == null || group.isEmpty;
        if (!hasError && _tasks.every((value) => value.name != group)) {
          final label = Group(group: group);
          _tasks.add(label);
          return await downLoader.downLoadByTag(<Label>[
            label,
            ...config.languages.map((e) => Language(name: e)),
            TypeLabel('doujinshi'),
            TypeLabel('manga')
          ], MapEntry('groupes', group), CancelToken(),
              onFinish: (success) => _tasks.remove(label));
        }
      } else if (result.wasParsed('tags')) {
        List<Label> tags = result["tags"]
            .map((e) => e.split(':'))
            .where((value) => value.length >= 2)
            .map((e) => fromString(e[0], e[1]))
            .toList();
        _tasks.addAll(tags);
        return downLoader.downLoadByTag(
            tags..addAll(config.languages.map((e) => Language(name: e))),
            MapEntry(tags.first.type, tags.first.name),
            CancelToken(),
            onFinish: (success) => _tasks.removeAll(tags));
      } else if (result.wasParsed('delete')) {
        List<String> delete = result["delete"];
        logger.d('delete ${delete}');
        return deleteByLabel(delete
            .map((e) => e.contains(":")
                ? fromString(e.substring(0, e.indexOf(':')),
                    e.substring(e.indexOf(':') + 1))
                : QueryText(e))
            .toList());
      } else if (result['fixDb']) {
        final count = await DirScanner(config, helper, downLoader, manager)
            .fixMissDbRow();
        logger.d("database fix ${count}");
      } else if (result['fixDup']) {
        final count = await DirScanner(config, helper, downLoader, manager)
            .removeDupGallery();
        logger.d("database fix ${count}");
        return count;
      } else if (result['fix']) {
        return await fixGallerys().then((value) => value > 0);
      } else if (result['update']) {
        return await fetchTagsFromNet()
            .then((value) => helper.updateTagTable(value));
      } else if (result['continue']) {
        return await runRemainTask().then((value) => value > 0);
      } else if (result['list']) {
        return <String, dynamic>{
          "queryTask": _tasks
              .map((e) => {'href': '/${e.urlEncode()}-all.html', ...e.toMap()})
              .toList(),
          "pendingTask": downLoader.pendingTask
              .map((t) => {
                    'href': t.gallery.galleryurl!,
                    'name': t.gallery.dirName,
                    'gallery': t.gallery
                  })
              .toList(),
          "runningTask": downLoader.runningTask
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
