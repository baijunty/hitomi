export 'src/hitomi.dart' show Hitomi;
export 'src/user_config.dart';
export 'src/http_server.dart';

extension IntParse on dynamic {
  int toInt() {
    if (this is int) {
      return this as int;
    }
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

extension StreamConvert<E> on Iterable<E> {
  Stream<E> asStream() => Stream.fromIterable(this);
}

extension NullFillterIterable<E, R> on Iterable<E?> {
  Iterable<R> mapNonNull(R? test(E? event)) =>
      this.map((e) => test(e)).where((element) => element != null)
          as Iterable<R>;
}

extension NullMapStream<E, R> on Stream<E> {
  Stream<R> mapNonNull(R? test(E event)) =>
      this.map((e) => test(e)).where((element) => element != null) as Stream<R>;
}

extension NullFillterStream<E> on Stream<E?> {
  Stream<E> filterNonNull() =>
      this.where((element) => element != null).map((event) => event!);
}

final zhAndJpCodeExp = RegExp(r'[\u0800-\u4e00|\u4e00-\u9fa5|30A0-30FF|\w]+');
final blankExp = RegExp(r'\s+');
final numberExp = RegExp(r'^\d+$');
