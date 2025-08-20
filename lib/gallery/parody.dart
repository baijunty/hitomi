import 'dart:convert';

import 'package:hitomi/gallery/label.dart';

class Parody with Label {
  final String parody;

  Parody({required this.parody});

  factory Parody.fromMap(Map<String, dynamic> data) => Parody(
        parody: (data['parody'] ?? data['series']) as String,
      );

  /// `dart:convert`
  ///
  /// Parses the string and returns the resulting Json object as [Parody].
  factory Parody.fromJson(String data) {
    return Parody.fromMap(json.decode(data) as Map<String, dynamic>);
  }

  /// `dart:convert`
  ///
  /// Converts [Parody] to a JSON string.
  String toJson() => json.encode(toMap());

  Parody copyWith({
    String? parody,
  }) {
    return Parody(
      parody: parody ?? this.parody,
    );
  }

  @override
  String get type => 'series';

  @override
  String get sqlType => 'parody';
  @override
  String get name => parody;
}
