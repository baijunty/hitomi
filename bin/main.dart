import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:hitomi/lib.dart';
import 'package:path/path.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o', defaultsTo: r'galleries', help: 'set output path with -p')
    ..addOption('proxy', abbr: 'p', defaultsTo: '', help: 'set proxy with -o')
    ..addOption('max',
        abbr: 'm', defaultsTo: '5', help: 'set max running tasks -o')
    ..addMultiOption('languages',
        abbr: 'l',
        defaultsTo: ["japanese", "chinese"],
        allowed: ["japanese", "chinese", "english"],
        help: 'set language with -l')
    ..addMultiOption('task', abbr: 't', help: 'set task with -t');
  ArgResults argResults = parser.parse(args);
  print(parser.usage);
  final outDir = argResults['output'];
  final proxy = argResults['proxy'];
  final List<String> languages = argResults["languages"];
  final List<String>? tasks = argResults["task"];
  UserConfig config;
  File file = File(join(outDir, 'config.json'));
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
  final task = TaskManager(config);
  tasks?.forEach(
      (element) async => await (await task.parseCommandAndRun(element.trim())));
  run_server(task);
  getUserInputId().forEach((element) async {
    task.logger.i(
        '\x1b[47;31madd command ${element.trim()} return ${await task.parseCommandAndRun(element.trim())} \x1b[0m');
  });
  await task.parseCommandAndRun('-c');
  // var len = await readIdFromFile(pool)
  //     .asStream()
  //     .expand((element) => element)
  //     .asyncMap((event) async {
  //   return await pool.parseCommandAndRun("-a \'$event\'");
  // }).length;
  // print(len);
}

Future<Iterable<String>> readIdFromFile(TaskManager manager) {
  return File('artist.txt').readAsLines().then((event) {
    return manager.helper
        .selectSqlMultiResultAsync(
            'select 1 from Gallery g where json_value_contains(g.artist,?)=1',
            event.map((e) => [e]).toList())
        .then(
            (value) => value.entries.where((element) => element.value.isEmpty))
        .then((value) => value.map((e) => e.key.first as String));
  });
}

Stream<String> getUserInputId() {
  return stdin
      .map((data) => systemEncoding.decode(data))
      .map((s) => s.split(';'))
      .expand((l) => l.toSet())
      .where((event) => event.trim().isNotEmpty);
}
