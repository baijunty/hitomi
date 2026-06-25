import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart';

import 'gallery/gallery.dart';

export 'src/user_config.dart';
export 'src/http_server.dart';
export 'src/task_manager.dart';
export 'src/hitomi_api.dart';
export 'src/response.dart';
export 'src/dhash.dart';
export 'src/sqlite_helper.dart';

extension IntParse on Object {
  int toInt() {
    if (this is int) {
      return this as int;
    }
    return int.parse(toString());
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

extension Filter<E> on Iterable<E> {
  Iterable<T> filterInstance<T>() {
    return where((element) => element is T).map((element) => element as T);
  }
}

extension CursorCover on IteratingCursor {
  Stream<Row> asStream(CommonPreparedStatement statement, [Logger? logger]) {
    late StreamController<Row> controller;
    var launch = true;
    bool statementClosed = false;
    void stop() {
      if (!statementClosed) {
        statement.close();
        statementClosed = true;
      }
    }

    Future<void> start() async {
      try {
        while (moveNext() && launch) {
          controller.add(current);
          // 每处理一行后让出事件循环，避免阻塞消费者造成背压问题
          await Future<void>.value();
        }
        if (launch) {
          controller.close();
        }
      } catch (e) {
        logger?.e('handle row error $e');
        controller.addError(e);
        // 发生错误时也关闭 statement，避免资源泄漏
        stop();
      }
    }

    void onResume() {
      launch = true;
      start();
    }

    void onPause() {
      launch = false;
    }

    controller = StreamController<Row>(
      onListen: start,
      onCancel: stop,
      onPause: onPause,
      onResume: onResume,
    );

    return controller.stream;
  }
}

Future<Gallery> readGalleryFromPath(String path, Logger? logger) {
  return File(
    p.join(path, 'meta.json'),
  ).readAsString().then((value) => Gallery.fromJson(value)).catchError((e) {
    logger?.e('open $path meta.json error');
    throw e;
  }, test: (error) => true);
}

extension StreamConvert<E> on Iterable<E> {
  Stream<E> asStream() => Stream.fromIterable(this);
}

extension NullMapStream<E, R> on Stream<E> {
  Stream<R> mapNonNull(R? test(E event)) =>
      this.map((e) => test(e)).where((element) => element != null) as Stream<R>;
}

extension NullFillterStream<E> on Stream<E?> {
  Stream<E> filterNonNull() =>
      this.where((element) => element != null).map((event) => event!);
}

extension FilterSteam<E> on Stream<E> {
  Stream<T> filterInstance<T>() {
    return where((element) => element is T).map((element) => element as T);
  }
}

extension HttpInvoke<T> on Dio {
  Future<T> httpInvoke<T>(
    String url, {
    Map<String, dynamic>? headers = null,
    CancelToken? token,
    void onProcess(int now, int total)?,
    String method = "get",
    Object? data = null,
    Logger? logger,
    void Function(Headers)? responseHead = null,
  }) async {
    final ua = {
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36 Edg/106.0.1370.47',
    };
    headers?.addAll(ua);
    ResponseType responseType;
    if (T == ResponseBody) {
      responseType = ResponseType.stream;
    } else if (T == List<int>) {
      responseType = ResponseType.bytes;
    } else if (T == String) {
      responseType = ResponseType.plain;
    } else {
      responseType = ResponseType.json;
    }
    // logger?.d('$url with $responseType');
    final useHeader = headers ?? ua;
    return (method == 'get'
            ? this.get<T>(
                url,
                options: Options(
                  headers: useHeader,
                  responseType: responseType,
                ),
                cancelToken: token,
                onReceiveProgress: onProcess,
              )
            : this.post<T>(
                url,
                options: Options(
                  headers: useHeader,
                  responseType: responseType,
                ),
                data: data,
                cancelToken: token,
                onReceiveProgress: onProcess,
              ))
        .then((value) {
          responseHead?.call(value.headers);
          return value.data!;
        })
        .catchError((e) {
          throw e;
        }, test: (e) => true);
  }
}

Map<String, String> buildRequestHeader(
  String url,
  String referer, {
  MapEntry<int, int>? range = null,
  void append(Map<String, String> header)?,
}) {
  Uri uri = Uri.parse(url);
  final headers = {
    'referer': referer,
    'authority': uri.authority,
    'path': uri.path,
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36 Edg/106.0.1370.47',
  };
  if (range != null) {
    headers.putIfAbsent('range', () => 'bytes=${range.key}-${range.value}');
  }
  if (append != null) {
    append(headers);
  }
  return headers;
}

final zhAndJpCodeExp = RegExp(r'[\u0800-\u4e00|\u4e00-\u9fa5|30A0-30FF]+');
final blankExp = RegExp(r'\s+');
final numberExp = RegExp(r'^\d+$');
final imageExtension = [
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.bmp',
  '.avif',
  '.gif',
  '.bmp',
];

final zhNum = '零〇一二三四五六七八九十';
final chapterRex = RegExp(
  r'第?\s*(?<start>[零〇一二三四五六七八九十|\d]{1,})\s*-?\s*(?<end>[零〇一二三四五六七八九十|\d]*)\s*(?<unit>[章|回|话|話|編|巻|集]*)',
);
const int readHistoryMask = 1 << 13;
const int bookMarkMask = 1 << 14;
const int lateReadMark = 1 << 16;
const int admarkMask = 1 << 17;
