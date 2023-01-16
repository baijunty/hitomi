import 'dart:io';
import 'dart:isolate';
import 'package:dart_tools/hitomi.dart';

Future<void> asyncDownload(SendPort port) async {
  final receivePort = ReceivePort();
  port.send(receivePort.sendPort);
  late Hitomi api;
  await receivePort.listen((element) async {
    print(element);
    if (element is String) {
      var b = await api.downloadImages(element);
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
    {String proxy = '', Map<String, String>? headers = null}) async {
  final client = HttpClient()
    ..connectionTimeout = Duration(seconds: 60)
    ..findProxy = (u) => proxy.isEmpty ? 'DIRECT' : 'PROXY $proxy';
  return client
      .getUrl(Uri.parse(url))
      .then((client) {
        headers?.forEach((key, value) {
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
        client.close();
        throw 'error code ${resp.statusCode}';
      })
      .whenComplete(() => client.close())
      .catchError((err) {
        client.close();
        throw err;
      });
}
