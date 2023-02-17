import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/src/sqlite_helper.dart';

import 'http_tools.dart';

class UserContext {
  static final _regExp = RegExp(r"case\s+(\d+):$");
  static final _codeExp = RegExp(r"b:\s+'(\d+)\/'$");
  static final _valueExp = RegExp(r"var\s+o\s+=\s+(\d);");
  late String code;
  late List<int> codes;
  late int index;
  late Timer _timer;
  late SqliteHelper _helper;
  int galleries_index_version = 0;
  List<Language> _languages = [Language.japanese, Language.chinese];
  String _proxy = 'DIRECT';
  Directory _output = Directory.current;
  List<Language> get languages => _languages;
  String get proxy => _proxy;
  Directory get outPut => _output;
  SqliteHelper get helper => _helper;
  UserContext(String output, {String? proxy, List<Language>? languages}) {
    _output = Directory(output);
    _output.createSync();
    _proxy = proxy ?? _proxy;
    _languages = languages ?? _languages;
    _helper = SqliteHelper(this);
    _timer = Timer.periodic(
        Duration(minutes: 30), (timer) async => await initData());
  }

  UserContext.fromJson(Map<String, dynamic> config) {
    if (config.containsKey('languages')) {
      _languages = (config['languages'] as List<dynamic>)
          .map((e) => Language.fromJson(e))
          .toList();
    }
    if (config.containsKey('proxy')) {
      _proxy = config['proxy'];
    }
    if (config.containsKey('output')) {
      _output = Directory(config['output']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["languages"] = languages;
    _data["proxy"] = proxy;
    _data["output"] = outPut.path;
    return _data;
  }

  Future<void> initData() async {
    final gg = await http_invke('https://ltn.hitomi.la/gg.js', proxy: proxy)
        .then((ints) {
          return Utf8Decoder().convert(ints);
        })
        .then((value) => LineSplitter.split(value))
        .then((value) => value.toList());
    final codeStr = gg.lastWhere((element) => _codeExp.hasMatch(element));
    code = _codeExp.firstMatch(codeStr)![1]!;
    var valueStr = gg.firstWhere((element) => _valueExp.hasMatch(element));
    index = int.parse(_valueExp.firstMatch(valueStr)![1]!);
    codes = gg
        .where((element) => _regExp.hasMatch(element))
        .map((e) => _regExp.firstMatch(e)![1]!)
        .map((e) => int.parse(e))
        .toList();
    galleries_index_version = await http_invke(
            'https://ltn.hitomi.la/galleriesindex/version?_=${DateTime.now().millisecondsSinceEpoch}',
            proxy: proxy)
        .then((value) => Utf8Decoder().convert(value))
        .then((value) => int.parse(value));
  }
}
