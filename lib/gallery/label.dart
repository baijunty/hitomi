import '../gallery/artist.dart';
import '../gallery/character.dart';
import '../gallery/group.dart';
import '../gallery/parody.dart';
import '../gallery/tag.dart';

abstract mixin class Lable {
  String get type;
  String get name;
  final Map<String, dynamic> trans = {};
  String get translate => trans['translate'] ?? name;
  String get intro => trans['intro'] ?? '';
  int get index => (trans['id'] as int?) ?? -1;
  String get sqlType => type;
  List<String> get params => [sqlType, name];
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

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Lable) return false;
    return this.type == other.type && this.name == other.name;
  }
}

Lable fromString(String type, String name) {
  switch (type) {
    case 'female':
    case 'male':
    case 'tag':
      return Tag(
          male: type == 'male' ? 1 : null,
          female: type == 'female' ? 1 : null,
          tag: name);
    case 'parody':
      return Parody(parody: name);
    case 'artist':
      return Artist(artist: name);
    case 'character':
      return Character(character: name);
    case 'group':
      return Group(group: name);
    case 'type':
      return TypeLabel(name);
    default:
      return QueryText(name);
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
