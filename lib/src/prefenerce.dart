import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:hitomi/src/user_config.dart';

import 'http_tools.dart';

class UserContext {
  static final _regExp = RegExp(r"case\s+(\d+):$");
  static final _codeExp = RegExp(r"b:\s+'(\d+)\/'$");
  static final _valueExp = RegExp(r"var\s+o\s+=\s+(\d);");
  late String code;
  late List<int> codes;
  late int index;
  late SqliteHelper _helper;
  int galleries_index_version = 0;
  List<Language> get languages =>
      _config.languages.map((e) => Language(name: e)).toList();
  String get proxy => _config.proxy;
  String get outPut => _config.output;
  final UserConfig _config;
  SqliteHelper get helper => _helper;
  UserContext(this._config) {
    Directory(_config.output)..createSync();
    _helper = SqliteHelper(this);
    Timer.periodic(Duration(minutes: 30), (timer) async => await initData());
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
