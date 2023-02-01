import 'dart:io';
import 'package:hitomi/gallery/language.dart';

class UserContext {
  List<Language> _languages = [Language.japanese, Language.chinese];
  String _proxy = 'DIRECT';
  Directory _output = Directory.current;
  List<Language> get languages => _languages;
  String get proxy => _proxy;
  Directory get outPut => _output;
  UserContext(String output, {String? proxy, List<Language>? languages}) {
    _output = Directory(output);
    _output.createSync();
    _proxy = proxy ?? _proxy;
    _languages = languages ?? _languages;
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
}
