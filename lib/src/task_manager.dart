import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/group.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/downloader.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqlite3/common.dart';

import '../gallery/gallery.dart';
import '../gallery/language.dart';
import '../gallery/parody.dart';
import '../gallery/tag.dart';
import 'dhash.dart';
import 'dir_scanner.dart';

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
  late Hitomi api;
  late DateTime limit = DateTime.parse(config.dateLimit);
  late Logger logger;
  late IsolateManager<MapEntry<int, List<int>?>, String> manager;
  late bool Function(Gallery) filter = (Gallery gallery) =>
      !downLoader.containsIlleagalTags(
          gallery, config.excludes.keys.toList()) &&
      DateTime.parse(gallery.date).compareTo(limit) > 0 &&
      (gallery.artists?.length ?? 0) <= 2 &&
      gallery.files.length >= 18;
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
            noBoxingByDefault: true));
    api = Hitomi.fromPrefenerce(config.output, config.languages,
        proxy: config.proxy, logger: logger);
    helper = SqliteHelper(config.output, logger: logger);
    manager = IsolateManager<MapEntry<int, List<int>?>, String>.create(
        _compressRunner,
        concurrent: config.maxTasks);
    downLoader = DownLoader(
        config: config,
        api: api,
        helper: helper,
        manager: this.manager,
        logger: logger);
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

  Future<dynamic> parseCommandAndRun(String cmd) async {
    bool hasError = false;
    var args = _parseArgs(cmd);
    logger.w('args $args');
    if (args.isEmpty) {
      return false;
    }
    final result = _parser.parse(args);
    if (numberExp.hasMatch(cmd)) {
      String id = cmd;
      hasError = !numberExp.hasMatch(id);
      if (!hasError) {
        await api
            .fetchGallery(id)
            .then((value) => downLoader.addTask(value))
            .catchError((e) {
          logger.e('add task $e');
        }, test: (error) => true);
      }
    } else if (result.wasParsed('artist')) {
      String? artist = result['artist'];
      hasError = artist == null || artist.isEmpty;
      if (!hasError) {
        await downLoader.downLoadByTag(<Lable>[
          Artist(artist: artist),
          ...config.languages.map((e) => Language(name: e)),
          TypeLabel('doujinshi'),
          TypeLabel('manga')
        ], filter, MapEntry('artist', artist));
      }
      return !hasError;
    } else if (result.wasParsed('group')) {
      String? group = result['group'];
      hasError = group == null || group.isEmpty;
      if (!hasError) {
        await downLoader.downLoadByTag(<Lable>[
          Group(group: group),
          ...config.languages.map((e) => Language(name: e)),
          TypeLabel('doujinshi'),
          TypeLabel('manga')
        ], filter, MapEntry('groupes', group));
      }
      return !hasError;
    } else if (result.wasParsed('tags')) {
      List<Lable> tags = result["tags"]
          .map((e) => e.split(':'))
          .where((value) => value.length >= 2)
          .map((e) => fromString(e[0], e[1]))
          .toList();
      downLoader.downLoadByTag(
          tags..addAll(config.languages.map((e) => Language(name: e))),
          filter,
          MapEntry(tags.first.type, tags.first.name));
      return !hasError;
    } else if (result.wasParsed('delete')) {
      List<String> delete = result["delete"];
      logger.d('delete ${delete}');
      delete
          .map((e) => e.contains(":")
              ? fromString(e.substring(0, e.indexOf(':')),
                  e.substring(e.indexOf(':') + 1))
              : QueryText(e))
          .forEach((element) async {
        late ResultSet galleryQuery;
        switch (element) {
          case QueryText():
            {
              downLoader.cancel(element.name);
              downLoader.removeTask(element.name);
              galleryQuery = await helper.queryGalleryById(element.name);
            }
          case Group():
            {
              downLoader.cancelByTag(element);
              galleryQuery =
                  await helper.queryGalleryByLabel('groupes', element);
            }
          case Parody():
            {
              downLoader.cancelByTag(element);
              galleryQuery =
                  await helper.queryGalleryByLabel('series', element);
            }
          case Tag():
            {
              downLoader.cancelByTag(element);
              galleryQuery = await helper.queryGalleryByLabel('tag', element);
            }
          default:
            {
              downLoader.cancelByTag(element);
              galleryQuery =
                  await helper.queryGalleryByLabel(element.sqlType, element);
            }
        }
        await galleryQuery
            .asStream()
            .asyncMap((event) => downLoader
                .readGalleryFromPath(join(config.output, event['path'])))
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
      });
    } else if (result['fixDb']) {
      final count =
          await DirScanner(config, helper, downLoader, manager).fixMissDbRow();
      logger.d("database fix ${count}");
    } else if (result['fixDup']) {
      final count = await DirScanner(config, helper, downLoader, manager)
          .removeDupGallery();
      logger.d("database fix ${count}");
      return count;
    } else if (result['fix']) {
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
          .asyncMap((event) {
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
          })
          .length;
      logger.d("scan finishd ${count}");
      return true;
    } else if (result['update']) {
      return await helper.updateTagTable(await api.fetchTagsFromNet());
    } else if (result['continue']) {
      var tasks = await helper
          .querySql('select id from Tasks where completed = ?', [0]);
      logger.d("left task ${tasks.length}");
      await Stream.fromIterable(tasks)
          .asyncMap((event) async {
            try {
              var r = await api.fetchGallery(event['id'], usePrefence: false);
              if (r.id.toString() != event['id'].toString()) {
                logger.d(' $event update to ${r.id}');
                await helper.removeTask(event['id']);
              }
              return r;
            } catch (e) {
              logger.d('fetchGallery error $e');
              await helper.removeTask(event['id']);
            }
            return null;
          })
          .filterNonNull()
          .forEach((value) async {
            var b = filter(value);
            if (!b) {
              logger.d('delete task $value');
              value.createDir(config.output).delete(recursive: true);
              await helper.removeTask(value.id);
            } else {
              downLoader.addTask(value);
            }
          });
    } else if (result['list']) {
      return downLoader.tasks;
    }
    if (hasError) {
      logger.e('$cmd error with ${args}');
    }
    return !hasError;
  }
}
