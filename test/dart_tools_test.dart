import 'dart:io';
import 'dart:math';
import 'package:dart_tools/galery_utils.dart';
import 'package:dart_tools/hitomi.dart';

void main() async {
  final List<Language> languages = [Language.japanese, Language.chinese];
  var config = UserPrefenerce(Directory.current.path,
      proxy: '127.0.0.1:8389', languages: languages);
  final pool = TaskPools(config);
  pool.sendNewTask('2129237');
  await Future.delayed(Duration(minutes: 10));
}

int idVerify(String id) {
  final v = id.runes
          .take(17)
          .toList()
          .asMap()
          .map((index, v) => MapEntry(
              index, _calIndex(index + 1) * int.parse(String.fromCharCode(v))))
          .values
          .fold(0, (int inc, v) => inc + v) %
      11;
  return (12 - v) % 11;
}

int _calIndex(int index) {
  num v = 17 - (index - 1);
  v = pow(2, v);
  v = v % 11;
  return v.toInt();
}
