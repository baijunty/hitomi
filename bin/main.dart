import 'dart:io';

import 'package:args/args.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/hitomi.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o',
        defaultsTo: r'/home/bai/ssd/photos',
        help: 'set output path with -p')
    ..addOption('proxy',
        abbr: 'p', defaultsTo: '127.0.0.1:8389', help: 'set proxy with -o')
    ..addOption('tasks',
        abbr: 't', defaultsTo: '5', help: 'set max running tasks -o')
    ..addMultiOption('languages',
        abbr: 'l',
        defaultsTo: ["japanese", "chinese"],
        allowed: ["japanese", "chinese", "english"],
        help: 'set language with -l');
  print(parser.usage);
  ArgResults argResults = parser.parse(args);
  final outDir = argResults['output'];
  final proxy = argResults['proxy'];
  final List<String> languages = argResults["languages"];
  var config = UserConfig(outDir,
      proxy: proxy,
      languages: languages,
      maxTasks: int.parse(argResults['tasks']));
  final pool = TaskManager(config);
  getUserInputId().forEach((element) async {
    final task = await pool.addNewTask(element.trim().toInt());
    task.listen((msg) {
      if (msg is DownLoadMessage) {
        var content =
            '${msg.id}下载${msg.title}${msg.current}/${msg.maxPage} ${(msg.speed).toStringAsFixed(2)}Kb/s 共${(msg.length / 1024).toStringAsFixed(2)}KB';
        var splitIndex = msg.maxPage == 0
            ? 0
            : (msg.current / msg.maxPage * content.length).toInt();
        print(
            '\x1b[47;31m${content.substring(0, splitIndex)}\x1b[0m${content.substring(splitIndex)}');
      }
    });
  });
}

Stream<String> getUserInputId() {
  final numbers = RegExp(r'^\d+$');
  return stdin
      .map((data) => systemEncoding.decode(data))
      .where((event) => numbers.hasMatch(event.trim()));
}
