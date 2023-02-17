import 'package:hitomi/src/sqlite_helper.dart';

abstract class Lable {
  String get type;
  String get name;
  final Map<String, dynamic> trans = const {};
  String get translate => trans['translate'] ?? name;
  String get intro => trans['intro'] ?? '';

  void translateLable(SqliteHelper helper) {
    final query = helper.getMatchLable(this);
    if (query != null) {
      trans.addAll(query);
    }
  }

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
