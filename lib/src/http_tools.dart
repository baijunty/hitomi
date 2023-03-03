import 'dart:io';

Future<List<int>> http_invke(String url,
    {String proxy = '',
    Map<String, dynamic>? headers = null,
    void onProcess(int now, int total)?}) async {
  final ua = {
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36 Edg/106.0.1370.47'
  };
  headers?.addAll(ua);
  final useHeader = headers ?? ua;
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
        client.close();
        throw error;
      })
      .whenComplete(() => client.close())
      .catchError((err) {
        client.close();
        if (err is HttpException) {
          return http_invke(url, proxy: proxy, headers: headers);
        }
        throw err;
      });
}
