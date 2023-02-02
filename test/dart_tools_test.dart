<<<<<<< HEAD
=======
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
>>>>>>> 88537fa (dhash fialed?)
import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';

void main() async {
  final List<Language> languages = [Language.japanese, Language.chinese];
  var config = UserContext('.', proxy: '127.0.0.1:8389', languages: languages);
  final hitomi = Hitomi.fromPrefenerce(config);
  // await _downFirstImage('1089557', 'test1.webp', hitomi);
  // await _downFirstImage('1089912', 'test2.webp', hitomi);
  // await _downFirstImage('2411838', 'test3.webp', hitomi);
  // await _downFirstImage('1014319', 'test4.webp', hitomi);
  // var ids = await hitomi.findSimilarGalleryBySearch();
  // await ids.forEach((element) {
  //   print(element);
  // });
}

Future<List<int>> _downFirstImage(String id, String name, Hitomi hitomi) async {
  final gallery = await hitomi.fetchGallery(id, usePrefence: false);
  var d = await hitomi.downloadImage(gallery.files.first,
      'https://hitomi.la/doujinshi/%E3%81%94%E6%B3%A8%E6%96%87%E3%81%AF%E7%B4%85%E8%8C%B6%E3%81%A7%E3%81%99%E3%81%8B---%E6%97%A5%E6%9C%AC%E8%AA%9E-1089557.html#1');
  File(name).writeAsBytesSync(d, flush: true);
  return d;
}
