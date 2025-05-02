import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
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
Future<List<int>?> _compressRunner(String imagePath) async {
  return File(imagePath)
      .readAsBytes()
      .then((value) => resizeThumbImage(value, 256))
      .catchError((e) => null, test: (error) => true);
}

class _MemoryOutputWrap extends MemoryOutput {
  _MemoryOutputWrap({super.secondOutput});

  @override
  Future<void> init() async {
    await secondOutput?.init();
    return super.init();
  }

  @override
  Future<void> destroy() async {
    await secondOutput?.destroy();
    return super.destroy();
  }
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
  final Set<Label> _queryTasks = <Label>{};
  final taskObserver = <Function(Map<String, dynamic>)>{};
  final Set<MapEntry<int, String>> _adImage = {};
  final _storage = InMemoryStorage<Label, Map<String, dynamic>>(1024);
  late SimpleCache<Label, Map<String, dynamic>> _cache =
      SimpleCache<Label, Map<String, dynamic>>(storage: _storage);
  final _reg = RegExp(r'!?\[(?<name>.*?)\]\(#*\s*\"?(?<url>\S+?)\"?\)');
  late IsolateManager<List<int>?, String> _manager;
  late _MemoryOutputWrap outputEvent;
  DownLoader get down => _downLoader;
  List<Map<String, dynamic>> get queryTask => _queryTasks
      .map((e) => {'href': '/${e.urlEncode()}-all.html', ...e.toMap()})
      .toList();
  Hitomi getApiDirect({bool local = false}) {
    return local ? _localApi : _api;
  }

  Hitomi getApiFromProxy(String auth, String proxyAddr) {
    return _webHitomi;
  }

  List<String> get adImage =>
      _adImage.map((e) => e.value).toList(growable: false);
  List<int> get adHash => _adImage.map((e) => e.key).toList(growable: false);

  void addTaskObserver(Function(Map<String, dynamic>) observer) {
    taskObserver.add(observer);
    logger.d('add observer now length ${taskObserver.length}');
  }

  void removeTaskObserver(Function(Map<String, dynamic>) observer) {
    taskObserver.remove(observer);
    logger.d('remove observer now length ${taskObserver.length}');
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
    if (config.logOutput.isNotEmpty) {
      outputEvent = _MemoryOutputWrap(
          secondOutput: FileOutput(
        file: File(config.logOutput),
        overrideExisting: true,
      ));
    } else {
      outputEvent = _MemoryOutputWrap(secondOutput: ConsoleOutput());
    }
    logger = Logger(
        filter: ProductionFilter(),
        output: outputEvent,
        level: level,
        printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 10,
            printEmojis: false,
            dateTimeFormat: DateTimeFormat.dateAndTime,
            noBoxingByDefault: true));
    _manager = IsolateManager<List<int>?, String>.create(_compressRunner,
        concurrent: config.maxTasks * 2);
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
        dio: dio,
        adImage: this._adImage,
        taskObserver: (msg) {
          if (taskObserver.isNotEmpty) {
            taskObserver.forEach((element) => element(msg));
          }
        });
    _parser = ArgParser()
      ..addFlag('fix')
      ..addFlag('fixDb')
      ..addFlag('fixDup')
      ..addFlag('update', abbr: 'u')
      ..addFlag('continue', abbr: 'c')
      ..addOption('pause', abbr: 'p')
      ..addOption('delete', abbr: 'd')
      ..addOption('artist', abbr: 'a')
      ..addOption('group', abbr: 'g')
      ..addOption('sqlite3', abbr: 's')
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
        var key = e.key;
        switch (key) {
          case 'mixed' || 'other' || 'cosplayer' || 'temp':
            {
              key = 'tag';
            }
          case 'reclass':
            key = 'type';
        }
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
    var row = await helper.querySql('select 1 from Gallery where id=?',
        [id]).then((value) => value.firstOrNull);
    if (row != null) {
      return [id];
    }
    var value = await _api.fetchGallery(id, usePrefence: false);
    return value.createDir(config.output, createDir: false).existsSync()
        ? readGalleryFromPath(
                value.createDir(config.output, createDir: false).path, logger)
            .then((value) => [value.id])
        : !value.hasAuthor
            ? down.computeImageHash([
                MultipartFile.fromBytes(
                    await _api
                        .fetchImageData(value.files.first)
                        .fold(<int>[], (acc, d) => acc..addAll(d)),
                    filename: value.files.first.name)
              ], config.aiTagPath.isEmpty).then((hash) {
                return helper.querySql(
                    '''SELECT gid FROM (SELECT gid, fileHash, ROW_NUMBER() OVER (PARTITION BY gid ORDER BY name) AS rn FROM GalleryFile where gid!=?) sub WHERE rn < 3 and hash_distance(fileHash,?) <5 limit 5''',
                    [
                      value.id,
                      hash[0]
                    ]).then((d) => d.map((r) => r['gid'] as int).toList());
              }).then((list) async {
                if (list.isEmpty) return [];
                var hashes = await Future.wait(list.map((id) =>
                    _localApi
                        .fetchGallery(id)
                        .then((g) => readGalleryFromPath(
                            g.createDir(config.output).path, logger))
                        .then((g) => fetchGalleryHash(g, down))
                        .then((e) => MapEntry(e.key.id, e.value)))).then((l) =>
                    l.fold(<int, List<int>>{}, (m, e) => m..[e.key] = e.value));
                return fetchGalleryHash(value, down, adHashes: adHash).then(
                    (v) => searchSimilerGaller(
                        MapEntry(v.key.id, v.value), hashes));
              })
            : fetchGalleryHash(value, down, adHashes: adHash).then((v) =>
                findDuplicateGalleryIds(
                    gallery: value,
                    helper: helper,
                    fileHashs: v.value,
                    logger: logger));
  }

  Future<List<int>> findSugguestGallery(int id) async {
    return config.aiTagPath.isNotEmpty
        ? await getApiDirect().fetchGallery(id).then((gallery) async {
            var idTitleMap = Map<int, String>();
            var ids = <int>[];
            if (gallery.artists != null) {
              await gallery.artists!
                  .asStream()
                  .asyncMap(
                      (event) => helper.queryGalleryByLabel('artist', event))
                  .map((event) => event.fold(
                      <int, String>{}, (acc, m) => acc..[m['id']] = m['title']))
                  .fold(idTitleMap, (map, item) => map..addAll(item));
            }
            if (gallery.groups != null) {
              await gallery.groups!
                  .asStream()
                  .asyncMap(
                      (event) => helper.queryGalleryByLabel('groupes', event))
                  .map((event) => event.fold(
                      <int, String>{}, (acc, m) => acc..[m['id']] = m['title']))
                  .fold(idTitleMap, (map, item) => map..addAll(item));
            }
            if (idTitleMap.isNotEmpty) {
              final formData = FormData.fromMap({
                "limit": 5,
                'threshold': 0.8,
                'docs': json
                    .encode([gallery.nameFixed, ...idTitleMap.values.toList()]),
                'process': 'feature'
              });
              var result = await dio
                  .post<List<dynamic>>('${config.aiTagPath}/evaluate',
                      data: formData,
                      options: Options(responseType: ResponseType.json))
                  .then((resp) => resp.data!)
                  .then((list) => list
                      .map((m) => m as Map<String, dynamic>)
                      .fold(
                          <MapEntry<String, double>>[],
                          (acc, m) => acc
                            ..add(MapEntry(m.keys.first, m.values.first))));
              logger.d('text similer search $result');
              result
                  .map((e) => idTitleMap.entries
                      .firstWhere((m) => m.value == e.key)
                      .key)
                  .fold(ids, (list, id) => list..add(id));
            }
            logger.d('$id text similer search done $ids');
            return await helper
                .querySql(
                    'select g.id,vector_distance(g1.feature,g.feature) as distance from Gallery g left join Gallery g1 on g1.id=? where g.id!=? order by vector_distance(g1.feature,g.feature) limit 5',
                    [id, id])
                .then((d) => d.map((r) => r['id'] as int).toList())
                .then((l) {
                  logger.d('vector_distance similer search done $l');
                  return ids..addAll(l);
                })
                .then((l) => l..remove(id));
          })
        : [];
  }

  Future<Map<Label, Map<String, dynamic>>> collectedInfo(List<Label> keys) {
    return keys
        .where((element) => !_cache.containsKey(element))
        .groupListsBy((element) => element.localSqlType)
        .entries
        .asStream()
        .asyncMap((entry) async {
      return helper
          .selectSqlMultiResultAsync(
              'select count(1) as count,g.date as date from Gallery g where exists (select 1 from GalleryTagRelation r where r.gid = g.id and r.tid = (select id from Tags where type = ? and name = ?))',
              entry.value.map((e) => [e.type, e.name]).toList())
          .then((value) {
        return value.entries.fold(<Label, Map<String, dynamic>>{},
            (previousValue, element) {
          final row = element.value.firstOrNull;
          if (row != null && row['date'] != null) {
            previousValue[fromString(element.key[0], element.key[1])] = {
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
        .fold(
            <String, List<HitomiDir>>{},
            (previous, element) => previous
              ..[element.gallery.id.toString()] =
                  ((previous[element.gallery.id.toString()] ?? [])
                    ..add(element)))
        .then((value) {
          return value
              .map((key, event) {
                var left = event.firstWhereOrNull((g) => g.gallery.hasAuthor) ??
                    event.first;
                event.removeWhere((g) => g == left);
                if (event.isNotEmpty) {
                  event.where((g) => g.dir.path != left.dir.path).forEach((e) {
                    logger.d(
                        'delete duplication ${e.gallery.id} with ${e.dir} left ${left.gallery}');
                    try {
                      e.dir.deleteSync(recursive: true);
                    } catch (err) {
                      logger.e('delete ${e.gallery.id} err ${err}');
                    }
                  });
                }
                return MapEntry(key, left);
              })
              .values
              .toList();
        })
        .asStream()
        .expand((l) => l)
        .asyncMap((g) => g.fixGallery())
        .length;
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

  Future<bool> addAdMark(List<String> hashes) async {
    var ads = hashes.where((s) => !adImage.contains(s)).toList();
    if (ads.isEmpty) return false;
    return ads
        .asStream()
        .asyncMap((hash) async => MultipartFile.fromBytes(
            await _api
                .fetchImageData(Image(
                    hash: hash,
                    hasavif: 0,
                    width: 0,
                    name: 'hash.jpg',
                    height: 0))
                .fold(<int>[], (acc, l) => acc..addAll(l)),
            filename: 'hash.jpg'))
        .fold(<MultipartFile>[], (fs, f) => fs..add(f))
        .then((fs) => down.computeImageHash(fs, config.aiTagPath.isEmpty))
        .then((values) {
          return values
              .mapIndexed((index, v) => MapEntry(ads[index], v))
              .where((e) =>
                  e.value != null &&
                  _adImage
                      .every((i) => compareHashDistance(e.value!, i.key) > 3))
              .asStream()
              .asyncMap((e) => helper.insertUserLog(
                  e.key.hashCode.abs() * -1, admarkMask,
                  value: e.value!, content: e.key))
              .fold(true, (acc, i) => acc && i);
        });
  }

  Future<bool> manageUserLog(List<Map<int, dynamic>> items, int type) async {
    return items
        .asStream()
        .asyncMap((item) => item['id'] > 0
            ? helper.insertUserLog(item['id'], type,
                value: item['mark'] ?? 0, content: item['content'])
            : helper.delete('UserLog', {'id': item['id'] * -1, 'type': type}))
        .fold(true, (fs, f) => fs && f);
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
              .then((value) async {
            if (value.gallery.id.toString() != id) {
              await helper.removeTask(id.toInt(), withGaller: true);
            }
            return true;
          }).catchError((e) {
            logger.e('add task $e');
            return false;
          }, test: (error) => true);
        }
      } else if (result.wasParsed('artist')) {
        String artist = result['artist'];
        hasError = artist.isEmpty == true;
        if (!hasError && _queryTasks.every((value) => value.name != artist)) {
          final label = Artist(artist: artist);
          _queryTasks.add(label);
          return _downLoader.downLoadByTag(<Label>[
            label,
            ...config.languages.map((e) => Language(name: e)),
            TypeLabel('doujinshi'),
            TypeLabel('manga')
          ], MapEntry('artist', artist), CancelToken(),
              onFinish: (success) async {
            _queryTasks.remove(label);
            _storage.remove(label);
            await translateLabel([label]);
          });
        }
      } else if (result.wasParsed('group')) {
        String group = result['group'];
        hasError = group.isEmpty;
        if (!hasError && _queryTasks.every((value) => value.name != group)) {
          final label = Group(group: group);
          _queryTasks.add(label);
          return _downLoader.downLoadByTag(<Label>[
            label,
            ...config.languages.map((e) => Language(name: e)),
            TypeLabel('doujinshi'),
            TypeLabel('manga')
          ], MapEntry('groupes', group), CancelToken(),
              onFinish: (success) async {
            _queryTasks.remove(label);
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
        _queryTasks.addAll(tags);
        return _downLoader.downLoadByTag(
            tags..addAll(config.languages.map((e) => Language(name: e))),
            MapEntry(tags.first.type, tags.first.name),
            CancelToken(),
            onFinish: (success) => _queryTasks.removeAll(tags));
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
        return remainTask().then((value) => value
            .where((g) => down.filter(g))
            .asyncMap((event) => _downLoader.addTask(event))
            .length);
      } else if (result.wasParsed('sqlite3')) {
        String command = result["sqlite3"];
        return helper.querySql(command).then((value) => value.toList());
      }
      if (hasError) {
        logger.e('$cmd error with ${args}');
      }
      return !hasError;
    } catch (e, stack) {
      logger.e('$e $stack');
      return false;
    }
  }
}
