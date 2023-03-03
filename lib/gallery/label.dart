import 'package:hitomi/src/sqlite_helper.dart';

abstract class Lable {
  String get type;
  String get name;
  final Map<String, dynamic> trans = {};
  String get translate => trans['translate'] ?? name;
  String get intro => trans['intro'] ?? '';
  int get index => (trans['id'] as int?) ?? -1;
  String get sqlType => type;

  void translateLable(SqliteHelper helper) {
    final query = helper.getMatchLable(this);
    if (query != null) {
      trans.addAll(query);
    }
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        type: name,
      };

  String urlEncode() {
    return "${this.type}/${Uri.encodeComponent(name.toLowerCase())}";
  }

  @override
  String toString() {
    return '{type:$type,name:$name,translate:$translate,intro:$intro}';
  }
}

class QueryText extends Lable {
  String text;
  QueryText(this.text);
  @override
  String get type => '';
  @override
  String get name => text;
}

class TypeLabel extends Lable {
  String typeName;
  TypeLabel(this.typeName);
  @override
  String get type => 'type';
  @override
  String get name => typeName;
}
