import 'dart:math';

void main() async {
  // final List<Language> languages = [Language.japanese, Language.chinese];
  // var config = UserPrefenerce(Directory.current.path,
  //     proxy: '127.0.0.1:8389', languages: languages);
  // final pool = TaskPools(config);
  // pool.sendNewTask('2129237');
  //await Future.delayed(Duration(minutes: 10));
  var r = Uri.encodeComponent('http://adf.com/第三方sdf has話早く');
  print(r);
  r = Uri.encodeQueryComponent('http://adf.com/第三方sdf has話早く');
  print(r);
  r = Uri.encodeFull('http://adf.com/第三方sdf has話早く');
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
