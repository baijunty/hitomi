import 'dart:convert';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/src/http_tools.dart';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tuple/tuple.dart';

import 'prefenerce.dart';

class SqliteHelper {
  final UserContext context;
  late final Database _db;
  SqliteHelper(this.context) {
    final dbPath = join(context.outPut.path, 'user.db');
    _db = sqlite3.open(dbPath);
  }

  Future<bool> updateTagTable() async {
    _db.execute('''create table  if not exists Tags(
      type TEXT NOT NULL,
      name TEXT NOT NULL,
      translate TEXT NOT NULL,
      intro TEXT NOT NULL,
      PRIMARY KEY (type,name)
      )''');
    // var rows = _db.select(
    //     'select intro from Tags where type=? by intro desc', ['author']);
    // Map<String, dynamic> author =
    //     (data['head'] as Map<String, dynamic>)['author'];
    final Map<String, dynamic> data = await http_invke(
            'https://github.com/EhTagTranslation/Database/releases/latest/download/db.text.json',
            proxy: context.proxy)
        .then((value) => Utf8Decoder().convert(value))
        .then((value) => json.decode(value));
    if (data['data'] is List<dynamic>) {
      var rows = data['data'] as List<dynamic>;
      final stam = _db.prepare(
          'REPLACE INTO Tags(type,name,translate,intro) values(?,?,?,?) ');
      rows
          .sublist(1)
          .map((e) => e as Map<String, dynamic>)
          .map((e) => Tuple2(
              e['namespace'] as String, e['data'] as Map<String, dynamic>))
          .fold<PreparedStatement>(stam, (st, e) {
        final key = ['mixed', 'other', 'cosplayer', 'temp'].contains(e.item1)
            ? 'tag'
            : e.item1.replaceAll('reclass', 'type');
        e.item2.entries.fold<PreparedStatement>(st, (previousValue, element) {
          final name = element.key;
          final value = element.value as Map<String, dynamic>;
          return previousValue
            ..execute([key, name, value['name'], value['intro']]);
        });
        return st;
      });
      stam.dispose();
    }
    return true;
  }

  Map<String, dynamic>? getMatchLable(Lable lable) {
    final set = _db.select(
        'select * from Tags where type=? and name=?', [lable.type, lable.name]);
    if (set.isNotEmpty) {
      return set.first;
    }
    return null;
  }
}
