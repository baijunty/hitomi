import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_tools/galery_utils.dart';
import 'package:dart_tools/hitomi.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o',
        defaultsTo: '/home/bai/ssd/photos',
        help: 'set output path with -p')
    ..addOption('proxy',
        abbr: 'p', defaultsTo: '127.0.0.1:8389', help: 'set proxy with -o')
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
  var config = UserPrefenerce(outDir,
      proxy: proxy,
      languages: languages.map((e) => Language.fromName(e)).toList());
  final pool = TaskPools(config);
  getUserInputId().forEach((element) {
    pool.sendNewTask(element.trim());
  });
}

Stream<String> getUserInputId() {
  final numbers = RegExp(r'\d+');
  return stdin
      .map((data) => systemEncoding.decode(data))
      .where((event) => numbers.hasMatch(event));
}
