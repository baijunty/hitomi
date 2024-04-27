import 'dart:convert';

import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';

import '../gallery/artist.dart';
import '../gallery/character.dart';
import '../gallery/group.dart';
import '../gallery/parody.dart';
import '../gallery/tag.dart';

abstract mixin class Label {
  String get type;
  String get name;
  String get sqlType => type;
  String get localSqlType => type;
  Map<String, dynamic>? translate;
  List<String> get params => [sqlType, name];
  Map<String, dynamic> toMap() => {'type': type, 'name': name, type: name};

  String urlEncode({SortEnum? sort}) {
    return "${this.type}/${sort == null || sort == SortEnum.Default ? '' : 'popular/${sort.name}/'}${Uri.encodeComponent(name.toLowerCase())}";
  }

  @override
  String toString() {
    return toMap().toString();
  }

  String toJson() => json.encode(toMap());

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Label) return false;
    return this.type == other.type && this.name == other.name;
  }
}

Label fromString(String type, String name) {
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
    case 'language':
      return Language(name: name);
    default:
      return QueryText(name);
  }
}

class QueryText extends Label {
  String text;
  QueryText(this.text);
  @override
  String get type => '';
  @override
  String get name => text;

  @override
  String urlEncode({SortEnum? sort}) {
    return '${sort == null || sort == SortEnum.Default ? 'index' : 'popular/${sort.name}'}';
  }
}

class TypeLabel extends Label {
  String typeName;
  TypeLabel(this.typeName);
  @override
  String get type => 'type';
  @override
  String get name => typeName;

  @override
  Map<String, dynamic> toMap() {
    return {type: type, 'name': typeName};
  }
}

class FilterLabel with Label {
  final String _type;
  final String _name;
  final double weight;

  FilterLabel(
      {required String type, required String name, required this.weight})
      : _type = type,
        _name = name;
  Map<String, dynamic> toMap() => {'type': type, 'name': name, 'weigt': weight};

  factory FilterLabel.fromMap(Map<String, dynamic> data) => FilterLabel(
        type: data['type'] as String,
        name: data['name'] as String,
        weight: data['weight'] as double,
      );

  factory FilterLabel.fromJson(String data) {
    return FilterLabel.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  @override
  String urlEncode({SortEnum? sort}) {
    return fromString(type, name).urlEncode(sort: sort);
  }

  @override
  String get name => _name;

  @override
  String get type => _type;
}
