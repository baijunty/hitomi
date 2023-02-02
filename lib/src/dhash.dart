import 'dart:typed_data';
import 'package:image/image.dart';

Future<String> imageHash(Uint8List data,
    {ImageHash hash = ImageHash.DHash, String? out}) async {
  final width = 9;
  final height = 8;
  final cmd = Command()
    ..decodeImage(data)
    ..copyResize(width: width, height: height)
    ..grayscale();
  if (out != null) {
    cmd.writeToFile(out);
  }
  final image = await cmd.getImage();
  final sb = StringBuffer();
  for (var i = 0; i < height; i++) {
    int code = 0;
    for (var j = 0; j < width - 1; j++) {
      final pixel = image!.getPixel(j, i).getChannel(Channel.luminance);
      final nextPixel = image.getPixel(j + 1, i).getChannel(Channel.luminance);
      code |= pixel < nextPixel ? 1 << (7 - j) : 0;
    }
    if (code < 16) {
      sb.write('0');
    }
    sb.write(code.toRadixString(16));
  }
  return sb.toString();
}

enum ImageHash { AHASH, DHash }
