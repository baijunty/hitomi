import 'dart:async';
import 'dart:isolate';
import 'package:args/args.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/group.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/downloader.dart';
import 'package:hitomi/src/sqlite_helper.dart';

import '../gallery/language.dart';

class TaskManager {
  final UserConfig config;
  final SendPort? port;
  late ArgParser _parser;
  late SqliteHelper helper;
  late DownLoader downLoader;
  late Hitomi api;
  late DateTime limit = DateTime.parse(config.dateLimit);
  ArgParser _command = ArgParser();
  TaskManager(this.config, [this.port]) {
    helper = SqliteHelper(config.output);
    api = Hitomi.fromPrefenerce(config);
    downLoader =
        DownLoader(config: config, api: api, helper: helper, port: port);
    _command
      ..addOption('name', abbr: 'n')
      ..addOption('type');
    _parser = ArgParser()
      ..addFlag('fix')
      ..addFlag('fixDb', abbr: 'f')
      ..addFlag('scan', abbr: 's')
      ..addFlag('update', abbr: 'u')
      ..addFlag('continue', abbr: 'c')
      ..addOption('del')
      ..addOption('artist', abbr: 'a')
      ..addOption('group', abbr: 'g')
      ..addMultiOption('tag', abbr: 't')
      ..addCommand('tags', _command);
  }

  void cancel() {
    downLoader;
  }

  List<String> _parseArgs(String cmd) {
    var words = cmd.split(blankExp);
    final args = <String>[];
    bool markCollct = false;
    final markWords = <String>{};
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

  Future<bool> parseCommandAndRun(String cmd) async {
    print('add command $cmd');
    bool hasError = false;
    var args = _parseArgs(cmd);
    if (args.isEmpty) {
      print('$cmd error with ${args}');
      print(_parser.usage);
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
        downLoader.addTask(id);
      }
    } else if (result.wasParsed('artist')) {
      String? artist = result['artist'];
      print(artist);
      hasError = artist == null || artist.isEmpty;
      if (!hasError) {
        await downLoader.downLoadByTag(
            <Lable>[
              Artist(artist: artist),
              ...config.languages.map((e) => Language(name: e)),
              TypeLabel('doujinshi'),
              TypeLabel('manga')
            ],
            (gallery) =>
                DateTime.parse(gallery.date).compareTo(limit) > 0 &&
                (gallery.artists?.length ?? 0) <= 2 &&
                gallery.files.length >= 18);
      }
      return !hasError;
    } else if (result.wasParsed('group')) {
      String? group = result['group'];
      print(group);
      hasError = group == null || group.isEmpty;
      if (!hasError) {
        await downLoader.downLoadByTag(
            <Lable>[
              Group(group: group),
              ...config.languages.map((e) => Language(name: e)),
              TypeLabel('doujinshi'),
              TypeLabel('manga')
            ],
            (gallery) =>
                DateTime.parse(gallery.date).compareTo(limit) > 0 &&
                (gallery.artists?.length ?? 0) <= 2 &&
                gallery.files.length >= 18);
      }
      return !hasError;
    } else if (result.command != null || result.wasParsed('tag')) {
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
        print('$tags');
        await downLoader.downLoadByTag(
            tags,
            (gallery) =>
                DateTime.parse(gallery.date).compareTo(limit) > 0 &&
                (gallery.artists?.length ?? 0) <= 2 &&
                gallery.files.length >= 18);
      }
    }
    // else if (result['fixDb']) {
    //   await fixDb();
    // } else if (result['fix']) {
    //   await fix();
    // }
    else if (result['update']) {
      print('start update db');
      return await helper.updateTagTable(await api.fetchTagsFromNet());
    } else if (result['continue']) {
      print('continue uncomplete task');
      var tasks = await helper
          .selectSqlAsync('select id from Tasks where completed = ?', [0]);
      tasks.forEach((element) {
        downLoader.addTask(element['id']);
      });
    }
    if (hasError) {
      print('$cmd error with ${args}');
      print(_parser.usage);
    }
    return !hasError;
  }
}
