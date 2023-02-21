export 'src/hitomi.dart' show Hitomi;
export 'src/prefenerce.dart';
export 'src/gallery_tool.dart';
export 'src/user_config.dart';

extension IntParse on String {
  int toInt() {
    return int.parse(this);
  }
}
