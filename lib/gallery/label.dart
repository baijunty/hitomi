import 'dart:convert';

import '../gallery/artist.dart';
import '../gallery/character.dart';
import '../gallery/group.dart';
import '../gallery/parody.dart';
import '../gallery/tag.dart';

abstract mixin class Lable {
  String get type;
  String get name;
  String? translate;
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
    return toMap().toString();
  }

  String toJson() => json.encode(toMap());

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
    case 'series':
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
