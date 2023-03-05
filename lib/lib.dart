export 'src/hitomi.dart' show Hitomi, Message;
export 'src/prefenerce.dart';
export 'src/gallery_tool.dart';
export 'src/user_config.dart';

extension IntParse on String {
  int toInt() {
    return int.parse(this);
  }
}

extension Comparable on Iterable<int> {
  int compareTo(Iterable<int> other) {
    final v1 = this.iterator;
    final v2 = other.iterator;
    while (v1.moveNext() && v2.moveNext()) {
      if (v1.current > v2.current) {
        return 1;
      } else if (v1.current < v2.current) {
        return -1;
      }
    }
    return 0;
  }
}

final zhAndJpCodeExp = RegExp(r'[\u0800-\u4e00|\u4e00-\u9fa5|30A0-30FF|\w]+');
final blankExp = RegExp(r'\s+');
final numberExp = RegExp(r'^\d+$');
