import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hitomi/gallery/label.dart';

@immutable
class Group with Lable {
  final String group;
  final String? url;

  const Group({required this.group, this.url});

  @override
  String toString() => 'Group(group: $group, url: $url)';

  factory Group.fromMap(Map<String, dynamic> data) => Group(
        group: data['group'] as String,
        url: data['url'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'group': group,
        'url': url,
      };

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Group].
  factory Group.fromJson(String data) {
    return Group.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Group] to a JSON string.
  String toJson() => json.encode(toMap());

  Group copyWith({
    String? group,
    String? url,
  }) {
    return Group(
      group: group ?? this.group,
      url: url ?? this.url,
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
  int get hashCode => group.hashCode ^ url.hashCode;

  @override
  String get type => 'group';

  @override
  String get name => group;
}
