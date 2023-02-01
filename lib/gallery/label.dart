abstract class Lable {
  String get type;
  String get name;

  String urlEncode() {
    return "${this.type}/${Uri.encodeComponent(name.toLowerCase())}";
  }

  @override
  String toString() {
    return '{type:$type,name:$name}';
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
