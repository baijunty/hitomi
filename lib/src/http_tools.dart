import 'dart:io';
import 'dart:isolate';
import 'hitomi.dart';

Future<void> asyncDownload(SendPort port) async {
  final receivePort = ReceivePort();
  port.send(receivePort.sendPort);
  late Hitomi api;
  await receivePort.listen((element) async {
    print(element);
    if (element is String) {
      var b = await api.downloadImagesById(element);
      Isolate.exit(port, b);
    } else if (element is Hitomi) {
      api = element;
    }
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
    {String proxy = '', Map<String, dynamic>? headers = null}) async {
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
          return resp.fold<List<int>>(<int>[], (l, ints) {
            l.addAll(ints);
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
        throw err;
      });
}
