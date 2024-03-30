import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

class Group with Label {
  final String group;

  Group({required this.group});

  factory Group.fromMap(Map<String, dynamic> data) => Group(
        group: data['group'] as String,
      );

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Group].
  factory Group.fromJson(String data) {
    return Group.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  Group copyWith({
    String? group,
  }) {
    return Group(
      group: group ?? this.group,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Group) return false;
    final mapEquals = const DeepCollectionEquality().equals;
    return mapEquals(other.toMap(), toMap());
  }

  @override
  int get hashCode => group.hashCode;

  @override
  String get type => 'group';

  @override
  String get localSqlType => 'groupes';

  @override
  String get name => group;
}
