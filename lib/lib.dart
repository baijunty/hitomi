import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:sqlite3/sqlite3.dart';

import 'gallery/gallery.dart';

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

extension CursorCover on IteratingCursor {
  Stream<Row> asStream(PreparedStatement statement, [Logger? logger]) {
    late StreamController<Row> controller;

    void stop() {
      statement.dispose();
    }

    void start() {
      try {
        while (moveNext()) {
          controller.add(current);
        }
        controller.close();
      } catch (e) {
        logger?.e('handle row error $e');
        controller.addError(e);
      }
    }

    controller = StreamController<Row>(onListen: start, onCancel: stop);

    return controller.stream;
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

sealed class Message<T> {
  final T id;
  Message({required this.id});

  @override
  String toString() {
    return 'Message {$id}';
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this)) return true;
    if (other is! Message) return false;
    return other.id == id;
  }
}

class TaskStartMessage<T> extends Message<int> {
  Gallery gallery;
  FileSystemEntity file;
  T target;
  TaskStartMessage(this.gallery, this.file, this.target)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'TaskStartMessage{$id,${file.path},${target}, ${gallery.files.length} }';
  }
}

class DownLoadingMessage extends Message<int> {
  Gallery gallery;
  int current;
  double speed;
  int length;
  DownLoadingMessage(this.gallery, this.current, this.speed, this.length)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'DownLoadMessage{$id,$current $speed,$length }';
  }
}

class DownLoadFinished<T> extends Message<int> {
  Gallery gallery;
  FileSystemEntity file;
  T target;
  bool success;
  DownLoadFinished(this.target, this.gallery, this.file, this.success)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'DownLoadFinished{$id,${file.path},${target} $success }';
  }
}

class IlleagalGallery extends Message<int> {
  String errorMsg;
  int index;
  IlleagalGallery(dynamic id, this.errorMsg, this.index) : super(id: id);
}

final zhAndJpCodeExp = RegExp(r'[\u0800-\u4e00|\u4e00-\u9fa5|30A0-30FF|\w]+');
final blankExp = RegExp(r'\s+');
final numberExp = RegExp(r'^\d+$');
