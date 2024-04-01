import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:hitomi/lib.dart';

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
    ..addMultiOption('task', abbr: 't', help: 'set task with -t');
  print(parser.usage);
  ArgResults argResults = parser.parse(args);
  final outDir = argResults['output'];
  final proxy = argResults['proxy'];
  final file = File(argResults['file']);
  final List<String> languages = argResults["languages"];
  final List<String>? tasks = argResults["task"];
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
  final pool = TaskManager(config);
  tasks?.forEach(
      (element) async => await (await pool.parseCommandAndRun(element.trim())));
  run_server(pool);
  getUserInputId().forEach((element) async {
    print(
        '\x1b[47;31madd command ${element.trim()} return ${await pool.parseCommandAndRun(element.trim())} \x1b[0m');
  });
  var lines = await File('fuck.log').readAsLines();
  lines.forEach((element) async {
    if (numberExp.hasMatch(element)) {
      var r = (await pool.parseCommandAndRun(element.trim()));
      print('add $element $r');
    } else {
      var r = (await pool.parseCommandAndRun("-a '$element'"));
      print('add $element $r');
    }
  });
  // var already = File('already.txt');
  // var writer = already.openWrite(mode: FileMode.append);
  // var len = await already
  //     .readAsLines()
  //     .then((value) => readIdFromFile(value))
  //     .asStream()
  //     .expand((element) => element)
  //     .asyncMap((event) async {
  //   var succ = await pool.parseCommandAndRun("-a \'$event\'");
  //   if (succ) {
  //     writer.writeln(event);
  //     await writer.flush();
  //   }
  // }).length;
  // print(len);
}

Future<Iterable<String>> readIdFromFile(List<String> downed) {
  return File('artist.txt')
      .readAsLines()
      .then((event) => event.where((element) => !downed.contains(element)));
}

Stream<String> getUserInputId() {
  return stdin
      .map((data) => systemEncoding.decode(data))
      .map((s) => s.split(';'))
      .expand((l) => l.toSet())
      .where((event) => event.trim().isNotEmpty);
}
