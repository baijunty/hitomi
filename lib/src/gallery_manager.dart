import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/group.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:tuple/tuple.dart';

import 'dhash.dart';

class GalleryManager {
  final UserContext context;
  final SendPort? port;
  late ArgParser parser;
  late SqliteHelper helper;
  ArgParser _command = ArgParser();
  GalleryManager(this.context, this.port) {
    _command
      ..addOption('name', abbr: 'n')
      ..addOption('type');
    parser = ArgParser()
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
    helper = SqliteHelper(this.context.config);
  }

  List<String> parseArgs(String cmd) {
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
    bool hasError = false;
    var args = parseArgs(cmd);
    if (args.isEmpty) {
      print('$cmd error with ${args}');
      print(parser.usage);
      return false;
    }
    final result = parser.parse(args);
    // if (result['scan']) {
    //   await listInfo();
    // } else if (numberExp.hasMatch(cmd)) {
    //   String id = cmd;
    //   hasError = !numberExp.hasMatch(id);
    //   if (!hasError) {
    //     hasError = !await downLoadGallery(id.toInt());
    //   }
    // } else if (result.wasParsed('del')) {
    //   String id = result['del'].trim();
    //   hasError = !numberExp.hasMatch(id);
    //   if (!hasError) {
    //     delGallery(id.toInt());
    //   }
    // } else
    if (result.wasParsed('artist')) {
      String? artist = result['artist'];
      print(artist);
      hasError = artist == null || artist.isEmpty;
      if (!hasError) {
        await downLoadByTag(
            <Lable>[
              Artist(artist: artist),
              ...context.languages,
              TypeLabel('doujinshi'),
              TypeLabel('manga')
            ],
            (gallery) =>
                DateTime.parse(gallery.date).compareTo(context.limit) > 0 &&
                (gallery.artists?.length ?? 0) <= 2 &&
                gallery.files.length >= 18);
      }
      return !hasError;
    } else if (result.wasParsed('group')) {
      String? group = result['group'];
      print(group);
      hasError = group == null || group.isEmpty;
      if (!hasError) {
        await downLoadByTag(
            <Lable>[
              Group(group: group),
              ...context.languages,
              TypeLabel('doujinshi'),
              TypeLabel('manga')
            ],
            (gallery) =>
                DateTime.parse(gallery.date).compareTo(context.limit) > 0 &&
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
        tags.addAll(context.languages);
        print('$tags');
        await downLoadByTag(
            tags,
            (gallery) =>
                DateTime.parse(gallery.date).compareTo(context.limit) > 0 &&
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
      return await helper.updateTagTable();
    } else if (result['continue']) {
      print('continue uncomplete task');
      var tasks = await helper
          .selectSqlAsync('select * from Tasks where completed = ?', [0]);
      for (var task in tasks) {
        await downLoadGallery(task['id']);
      }
    }
    if (hasError) {
      print('$cmd error with ${args}');
      print(parser.usage);
    }
    return !hasError;
  }

  Future<bool> downLoadGallery(int id) async {
    var lastDate = DateTime.now();
    return await context.api.downloadImagesById(id, onProcess: (msg) {
      var now = DateTime.now();
      if (now.difference(lastDate).inMilliseconds > 300) {
        lastDate = now;
        this.port?.send(msg);
      }
    });
  }

  Future<bool> downLoadByTag(
      List<Lable> tags, bool where(Gallery gallery)) async {
    final api = context.api;
    final results =
        await api.search(tags, exclude: context.exclude).then((value) async {
      print('serch result length ${value.length}');
      return await Stream.fromIterable(value)
          .asyncMap((event) async => await api.fetchGallery(event))
          .where((event) => where(event))
          .asyncMap((event) async {
        final img = await api.downloadImage(
            event.files.first.getThumbnailUrl(context),
            'https://hitomi.la${Uri.encodeFull(event.galleryurl!)}');
        var hash = await imageHash(Uint8List.fromList(img));
        return Tuple2(hash, event);
      }).fold<Map<Tuple2<int, Gallery>, Gallery>>({}, (previousValue, element) {
        previousValue.removeWhere((key, value) {
          if ((compareHashDistance(key.item1, element.item1) < 8 ||
                  key.item2 == element.item2) &&
              (element.item2.language == 'japanese' ||
                  element.item2.language == value.language)) {
            return true;
          }
          return false;
        });
        previousValue[element] = element.item2;
        return previousValue;
      }).then((value) async {
        var result = <Gallery>[];
        for (var entry in value.entries) {
          await helper.updateTask(entry.value, false);
          var downloaded = await helper.querySql(
                  'select 1 from Gallery where id =?', [entry.value.id]) !=
              null;
          if (downloaded) {
            await helper.removeTask(entry.value.id);
          } else {
            result.add(entry.value);
          }
        }
        return result;
      });
    });
    bool b = true;
    print('find length ${results.length}');
    for (var element in results) {
      b &= await api.downloadImagesById(element.id, usePrefence: false);
      if (b) {
        await helper.removeTask(element.id);
      } else {
        await helper.updateTask(element, true);
      }
    }
    return b;
  }
}
