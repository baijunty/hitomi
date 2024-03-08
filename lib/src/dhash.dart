import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:image/image.dart';

Future<int> imageHash(Uint8List data,
    {ImageHash hash = ImageHash.AHash,
    Interpolation interpolation = Interpolation.average}) async {
  final cmd = Command()
    ..decodeImage(data)
    ..copyResize(
        width: hash.width, height: hash.height, interpolation: interpolation)
    ..grayscale();
  final image = await cmd.getImage();
  final bits = hash.hash(image!).foldIndexed<int>(
      0, (index, acc, element) => acc |= element ? 1 << (63 - index) : 0);
  return bits;
}

Future<Uint8List?> resizeThumbImage(Uint8List data, int width,
    [int quality = 65]) async {
  final cmd = Command()
    ..decodeImage(data)
    ..copyResize(width: width, interpolation: Interpolation.average)
    ..encodeJpg(quality: quality);
  return cmd.getImage().then((value) => cmd.outputBytes);
  // final out = File(outPath);
  // if (out.existsSync()) {
  //   return out.readAsBytes().then((value) {
  //     // out.deleteSync();
  //     return value;
  //   });
  // }
}

int compareHashDistance(int hash1, int hash2) {
  int xor = hash1 ^ hash2;
  int distance = 0;
  while (xor != 0) {
    if (xor & 1 == 1) distance++;
    xor >>>= 1;
  }
  return distance;
}

abstract mixin class ImageHash {
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
    final acc = pixels.fold<num>(
        0, (previousValue, element) => previousValue + element);
    final average = acc / (width * height);
    return pixels.map((e) => e >= average).toList();
  }

  @override
  int get height => 8;

  @override
  int get width => 8;
}
