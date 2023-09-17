import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';

import 'http_tools.dart';

class UserContext {
  static final _regExp = RegExp(r"case\s+(\d+):$");
  static final _codeExp = RegExp(r"b:\s+'(\d+)\/'$");
  static final _valueExp = RegExp(r"var\s+o\s+=\s+(\d);");
  late String code;
  late List<int> codes;
  late int index;
  late Hitomi _hitomi;
  Map<Lable, List<int>> _cache = {};
  int galleries_index_version = 0;
  List<Language> get languages =>
      config.languages.map((e) => Language(name: e)).toList();
  String get proxy => config.proxy;
  String get outPut => config.output;
  Hitomi get api => _hitomi;
  List<Lable> exclude = [];
  final UserConfig config;
  DateTime get limit => (config.dateLimit?.isEmpty ?? true)
      ? DateTime(1970)
      : DateTime.parse(config.dateLimit!);
  UserContext(this.config) {
    Directory(config.output)..createSync();
    _hitomi = Hitomi.fromPrefenerce(this);
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

  Future<List<int>> getCacheIdsFromLang(Lable lable) async {
    if (!_cache.containsKey(lable)) {
      var result = await api.fetchIdsByTag(lable);
      print('fetch label ${lable.name} result ${result.length}');
      _cache[lable] = result;
    }
    return _cache[lable]!;
  }
}
