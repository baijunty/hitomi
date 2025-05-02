import 'package:freezed_annotation/freezed_annotation.dart';

part 'imagetagfeature.freezed.dart';
part 'imagetagfeature.g.dart';

@freezed
abstract class ImageTagFeature with _$ImageTagFeature {
  factory ImageTagFeature(
          String fileName, List<double>? data, Map<String, double>? tags) =
      _ImageTagFeature;

  factory ImageTagFeature.fromJson(Map<String, dynamic> json) =>
      _$ImageTagFeatureFromJson(json);
}
