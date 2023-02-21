import 'dart:io';
import 'dart:isolate';
import 'package:hitomi/src/prefenerce.dart';
import 'package:hitomi/src/user_config.dart';

import 'hitomi.dart';

Future<void> asyncDownload(SendPort port) async {
  final receivePort = ReceivePort();
  port.send(receivePort.sendPort);
  late Hitomi api;
  var lastDate = DateTime.now();
  await receivePort.listen((element) async {
    print(element);
    if (element is int) {
      await api.downloadImagesById(element, (msg) {
        var now = DateTime.now();
        if (now.difference(lastDate).inSeconds > 1) {
          lastDate = now;
          port.send(msg);
        }
      });
    } else if (element is UserConfig) {
      final prefenerce = UserContext(element);
      await prefenerce.initData();
      api = Hitomi.fromPrefenerce(prefenerce);
      port.send(true);
    }
  })
    ..onError((e) {
      port.send(false);
    });
}

List<int> mapBytesToInts(List<int> resp, {int spilt = 4}) {
  if (resp.length % spilt != 0) {
    throw 'not $spilt times';
  }
  final result = <int>[];
  for (var i = 0; i < resp.length / spilt; i++) {
    var subList = resp.sublist(i * spilt, i * spilt + spilt);
    int r = 0;
    for (var i = 0; i < subList.length; i++) {
      r |= subList[i] << (spilt - 1 - i) * 8;
    }
    result.add(r);
  }
  return result;
}

Future<List<int>> http_invke(String url,
    {String proxy = '',
    Map<String, dynamic>? headers = null,
    void onProcess(int now, int total)?}) async {
  final useHeader = headers ??
      {
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36 Edg/106.0.1370.47'
      };
  final client = HttpClient()
    ..connectionTimeout = Duration(seconds: 60)
    ..findProxy = (u) => proxy.isEmpty ? 'DIRECT' : 'PROXY $proxy';
  return client
      .getUrl(Uri.parse(url))
      .then((client) {
        useHeader.forEach((key, value) {
          client.headers.add(key, value);
        });
        return client.close();
      })
      .then((resp) {
        if (resp.statusCode == 200 || resp.statusCode == 206) {
          int total = resp.contentLength;
          return resp.fold<List<int>>(<int>[], (l, ints) {
            l.addAll(ints);
            onProcess?.call(l.length, total);
            return l;
          });
        }
        final error = '$url with $headers error ${resp.statusCode}';
        print(error);
        client.close();
        throw error;
      })
      .whenComplete(() => client.close())
      .catchError((err) {
        client.close();
        if (err is HttpException) {
          return http_invke(url, proxy: proxy, headers: headers);
        } else {
          throw err;
        }
      });
}
