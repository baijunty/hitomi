import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:image/image.dart';

Future<String> imageHash(Uint8List data,
    {ImageHash hash = ImageHash.AHash}) async {
  final cmd = Command()
    ..decodeImage(data)
    ..copyResize(
        width: hash.width,
        height: hash.height,
        interpolation: Interpolation.average)
    ..grayscale();
  final image = await cmd.getImage();
  final bits = hash.hash(image!);
  return bits
      .splitBeforeIndexed((index, element) => index % 8 == 0)
      .map((element) => element
          .foldIndexed<int>(
              0,
              (index, previousValue, element) =>
                  previousValue |= element ? (1 << (7 - index)) : 0)
          .toRadixString(16))
      .fold<StringBuffer>(StringBuffer(),
          (previousValue, element) => previousValue..write(element))
      .toString();
}

Future<int> distance(List<int> data1, List<int> data2,
    {ImageHash hash = ImageHash.AHash}) async {
  final hash1 = await imageHash(Uint8List.fromList(data1), hash: hash);
  final hash2 = await imageHash(Uint8List.fromList(data2), hash: hash);
  return Iterable.generate(hash1.length).fold<int>(
      0,
      (previous, element) =>
          previous + (hash2[element] == hash1[element] ? 0 : 1));
}

abstract class ImageHash {
  static const DHash = const _DHash();
  static const AHash = const _AHash();
  int get width;
  int get height;
  List<bool> hash(Image image);
}

class _DHash with ImageHash {
  const _DHash();
  @override
  List<bool> hash(Image image) {
    final result = <bool>[];
    for (var i = 0; i < height; i++) {
      for (var j = 0; j < width - 1; j++) {
        final pixel = image.getPixel(j, i).getChannel(Channel.luminance);
        final nextPixel =
            image.getPixel(j + 1, i).getChannel(Channel.luminance);
        result.add(pixel < nextPixel);
      }
    }
    return result;
  }

  @override
  int get height => 8;

  @override
  int get width => 9;
}

class _AHash with ImageHash {
  const _AHash();

  @override
  List<bool> hash(Image image) {
    final pixels = image.map((e) => e.getChannel(Channel.luminance)).toList();
    final average = pixels.fold<num>(
            0, (previousValue, element) => previousValue + element) /
        (width * height);
    return pixels.map((e) => e >= average).toList();
  }

  @override
  int get height => 8;

  @override
  int get width => 8;
}
