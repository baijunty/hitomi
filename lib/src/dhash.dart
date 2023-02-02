import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:image/image.dart';

Future<String> imageHash(Uint8List data) async {
  final width = 9;
  final height = 8;
  final cmd = Command()
    ..decodeImage(data)
    ..grayscale()
    ..copyResize(width: width, height: height);
  final image = await cmd.getImage();
  final result = <int>[];
  for (var i = 0; i < height; i++) {
    for (var j = 0; j < width - 1; j++) {
      final pixel = image!.getPixel(j, i).getChannel(Channel.luminance);
      final nextPixel = image.getPixel(j + 1, i).getChannel(Channel.luminance);
      result.add(pixel < nextPixel ? 1 : 0);
    }
  }
  print(result);
  return result
      .splitBeforeIndexed((index, element) => index % 8 == 0)
      .mapIndexed((index, element) => element.foldIndexed<int>(
          0, (index, previous, element) => previous | (element << index)))
      .map((i) => i.toRadixString(16))
      .fold<StringBuffer>(StringBuffer(), (previousValue, element) {
    previousValue..write(element);
    return previousValue;
  }).toString();
}
