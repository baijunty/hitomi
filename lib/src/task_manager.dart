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

import '../gallery/gallery.dart';
import '../gallery/language.dart';
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
      !(gallery.tags?.any((element) => config.excludes.contains(element.tag)) ??
          false) &&
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
    api = Hitomi.fromPrefenerce(config, logger: logger);
    helper = SqliteHelper(config.output);
    manager = IsolateManager<MapEntry<int, List<int>?>, String>.create(
        _compressRunner,
        concurrent: Platform.numberOfProcessors ~/ 2);
    downLoader = DownLoader(
        config: config,
        api: api,
        helper: helper,
        manager: this.manager,
        logger: logger);
    _parser = ArgParser()
      ..addFlag('fix')
      ..addFlag('fixDb', abbr: 'f')
      ..addFlag('scan', abbr: 's')
      ..addFlag('update', abbr: 'u')
      ..addFlag('continue', abbr: 'c')
      ..addOption('del')
      ..addOption('artist', abbr: 'a')
      ..addOption('group', abbr: 'g')
      ..addFlag('list', abbr: 'l')
      ..addMultiOption('tag', abbr: 't')
      ..addMultiOption('delete', abbr: 'd')
      ..addMultiOption('tags');
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
    print('\x1b[47;31madd command $cmd \x1b[0m');
    bool hasError = false;
    var args = _parseArgs(cmd);
    logger.d('args $args');
    if (args.isEmpty) {
      return false;
    }
    final result = _parser.parse(args);
    // if (result['scan']) {
    //   await listInfo();
    // }  else if (result.wasParsed('del')) {
    //   String id = result['del'].trim();
    //   hasError = !numberExp.hasMatch(id);
    //   if (!hasError) {
    //     delGallery(id.toInt());
    //   }
    // }
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
        downLoader.downLoadByTag(<Lable>[
          Artist(artist: artist),
          ...config.languages.map((e) => Language(name: e)),
          TypeLabel('doujinshi'),
          TypeLabel('manga')
        ], filter);
      }
      return !hasError;
    } else if (result.wasParsed('group')) {
      String? group = result['group'];
      hasError = group == null || group.isEmpty;
      if (!hasError) {
        downLoader.downLoadByTag(<Lable>[
          Group(group: group),
          ...config.languages.map((e) => Language(name: e)),
          TypeLabel('doujinshi'),
          TypeLabel('manga')
        ], filter);
      }
      return !hasError;
    } else if (result.wasParsed('tag')) {
      var name = result.command?['name'];
      var type = result.command?['type'];
      List<String> tagWords = result.wasParsed('tag') ? result['tag'] : [];
      hasError = name == null && tagWords.isEmpty;
      if (!hasError) {
        List<Lable> tags = [];
        if (type != null) {
          tags.add(fromString(type, name));
        } else if (name != null) {
          tagWords.add(name);
        }
        tags.addAll(await helper.fetchLablesFromSql(tagWords));
        tags.addAll(config.languages.map((e) => Language(name: e)));
        logger.d(tags);
        downLoader.downLoadByTag(tags, filter);
      }
      return !hasError;
    } else if (result.wasParsed('tags')) {
      List<String> tags = result["tags"];
      downLoader.downLoadByTag(
          tags
              .map((e) => e.split(':'))
              .where((value) => value.length >= 2)
              .map((e) => fromString(e[0], e[1]))
              .toList()
            ..addAll(config.languages.map((e) => Language(name: e))),
          filter);
      return !hasError;
    }
    // else if (result.wasParsed('delete')) {
    //   List<String> delete = result["delete"];
    // }
    // else if (result['fixDb']) {
    //   await fixDb();
    // }
    else if (result['fix']) {
      final count =
          await DirScanner(config, helper, downLoader, manager, logger)
              .listDirs()
              .filterNonNull()
              .asyncMap((element) => element.fixGallery())
              .fold(
                  <bool, int>{},
                  (previous, element) =>
                      previous..[element] = (previous[element] ?? 0) + 1);
      logger.d("scan finishd ${count}");
      return true;
    } else if (result['update']) {
      return await helper.updateTagTable(await api.fetchTagsFromNet());
    } else if (result['continue']) {
      var tasks = await helper
          .selectSqlAsync('select id from Tasks where completed = ?', [0]);
      tasks.forEach((element) async {
        await api
            .fetchGallery(element['id'])
            .then((value) => downLoader.addTask(value))
            .catchError((e) => logger.e('continue task $e'),
                test: (error) => true);
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
