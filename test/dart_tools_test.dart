import 'dart:convert';
import 'dart:math';
import 'package:dart_tools/http_tools.dart';

void main() async {
  var r = await http_invke(
          'https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=en&tl=zh-CN&q=yaoi',
          proxy: '127.0.0.1:8389')
      .then((value) {
    return Utf8Decoder().convert(value);
  });
  print(r);
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
