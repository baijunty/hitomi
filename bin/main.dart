import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/downloader.dart';
import 'package:hitomi/src/task_manager.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o',
        defaultsTo: r'/home/bai/ssd/photos',
        help: 'set output path with -p')
    ..addOption('proxy',
        abbr: 'p', defaultsTo: '127.0.0.1:8389', help: 'set proxy with -o')
    ..addOption('max',
        abbr: 'm', defaultsTo: '5', help: 'set max running tasks -o')
    ..addOption('file',
        abbr: 'f', defaultsTo: 'config.json', help: 'set config json path')
    ..addMultiOption('languages',
        abbr: 'l',
        defaultsTo: ["japanese", "chinese"],
        allowed: ["japanese", "chinese", "english"],
        help: 'set language with -l')
    ..addOption('task', abbr: 't', help: 'set task with -t');
  print(parser.usage);
  ArgResults argResults = parser.parse(args);
  final outDir = argResults['output'];
  final proxy = argResults['proxy'];
  final file = File(argResults['file']);
  final List<String> languages = argResults["languages"];
  final String? tasks = argResults["task"];
  UserConfig config;
  if (file.existsSync()) {
    config = UserConfig.fromStr(file.readAsStringSync());
  } else {
    config = UserConfig(outDir,
        proxy: proxy,
        languages: languages,
        maxTasks: int.parse(argResults['max']));
    file.writeAsBytesSync(json.encode(config.toJson()).codeUnits);
  }
  print(config);
  final recy = ReceivePort();
  final pool = TaskManager(config, recy.sendPort);
  tasks?.split(';').forEach(
      (element) async => await (await pool.parseCommandAndRun(element.trim())));
  recy.listen((msg) {
    // if (msg is DownLoadMessage) {
    //   var content =
    //       '${msg.id}下载${msg.title} ${msg.current}/${msg.maxPage} ${(msg.speed).toStringAsFixed(2)}Kb/s 共${(msg.length / 1024).toStringAsFixed(2)}KB';
    //   var splitIndex = msg.maxPage == 0
    //       ? 0
    //       : (msg.current / msg.maxPage * content.length).toInt();
    //   print(
    //       '\x1b[47;31m${content.substring(0, splitIndex)}\x1b[0m${content.substring(splitIndex)}');
    // }
    if (msg is DownLoadFinished) {
      print('${msg.id} is finished miss ${msg.missFiles}');
    }
  });
  getUserInputId().forEach((element) async {
    await pool.parseCommandAndRun(element.trim());
  });
}

Stream<String> getUserInputId() {
  return stdin
      .map((data) => systemEncoding.decode(data))
      .map((s) => s.split(';'))
      .expand((l) => l.toSet())
      .where((event) => event.trim().isNotEmpty);
}
