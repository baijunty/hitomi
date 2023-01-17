import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_tools/gallery.dart';
import 'package:image/image.dart' as img;

import 'http_tools.dart';

abstract class Hitomi {
  Future<bool> downloadImagesById(String id);
  Future<Gallery> fetchGallery(String id, {usePrefence = true});
  Stream<Gallery> search(List<Tag> args, [int page = 0]);
  Stream<Gallery> viewByTag(Tag tag, [int page = 0]);

  factory Hitomi.fromPrefenerce(UserPrefenerce prefenerce) {
    return _HitomiImpl(prefenerce);
  }

  Future<void> pause();
  Future<void> restart();
}

class UserPrefenerce {
  List<Language> languages;
  String proxy = 'DIRECT';
  String output;
  UserPrefenerce(this.output,
      {this.proxy = 'direct', this.languages = const [Language.chinese]});
}

class _HitomiImpl implements Hitomi {
  final UserPrefenerce prefenerce;
  static final _regExp = RegExp(r"case\s+(\d+):$");
  static final _codeExp = RegExp(r"b:\s+'(\d+)\/'$");
  static final _valueExp = RegExp(r"var\s+o\s+=\s+(\d);");
  late String code;
  late List<int> codes;
  late int index;
  Timer? _timer;
  _HitomiImpl(this.prefenerce);

  Future<Timer> initData() async {
    final gg =
        await http_invke('https://ltn.hitomi.la/gg.js', proxy: prefenerce.proxy)
            .then((ints) {
              return Utf8Decoder().convert(ints);
            })
            .then((value) => LineSplitter.split(value))
            .then((value) => value.toList());
    final codeStr = gg.lastWhere((element) => _codeExp.hasMatch(element));
    code = _codeExp.firstMatch(codeStr)![1]!;
    var valueStr = gg.firstWhere((element) => _valueExp.hasMatch(element));
    index = int.parse(_valueExp.firstMatch(valueStr)![1]!);
    codes = gg
        .where((element) => _regExp.hasMatch(element))
        .map((e) => _regExp.firstMatch(e)![1]!)
        .map((e) => int.parse(e))
        .toList();
    return Timer.periodic(Duration(minutes: 30), (timer) => initData());
  }

  Future<Map<String, dynamic>> _fetchGalleryJsonById(String id) async {
    _timer = _timer ?? await initData();
    return http_invke('https://ltn.hitomi.la/galleries/$id.js',
            proxy: prefenerce.proxy)
        .then((ints) {
          return Utf8Decoder().convert(ints);
        })
        .then((value) => value.indexOf("{") >= 0
            ? value.substring(value.indexOf("{"))
            : value)
        .then((value) {
          return jsonDecode(value);
        });
  }

  @override
  Future<bool> downloadImagesById(String id) async {
    final gallery = await fetchGallery(id);
    var artists = gallery.artists?[0].artist ?? '';
    final outPath = prefenerce.output;
    var dir;
    try {
      final title =
          '${artists.isEmpty ? '' : '($artists)'}${(gallery.japaneseTitle ?? gallery.title)?.replaceAll('/', ' ').replaceAll('.', '。').replaceAll('?', '!').replaceAll('*', '').replaceAll(':', ' ')}';
      dir = Directory("${outPath}/${title}")..createSync();
    } catch (e) {
      print(e);
      dir = Directory("${outPath}/${artists.isEmpty ? '' : '($artists)'}$id")
        ..createSync();
    }
    print(dir);
    File(dir.path + '/' + 'meta.json').writeAsStringSync(json.encode(gallery));
    final List<Files> images = gallery.files;
    final url = 'https://hitomi.la${Uri.encodeFull(gallery.galleryurl!)}';
    images.forEach((file) async {
      final out = File(dir.path + '/' + file.name);
      final b = await _checkViallImage(dir, file);
      if (!b) {
        var data = await downloadImage(file, url);
        await out.writeAsBytes(data, flush: true);
      }
    });
    print('下载完成');
    return images.isEmpty;
  }

  Future<bool> _checkViallImage(File dir, Files image) async {
    final out = File(dir.path + '/' + image.name);
    var b = await out.exists();
    img.Decoder? decoder;
    if (b) {
      decoder = img.findDecoderForNamedImage(out.path);
    }
    if (decoder != null) {
      var size = min(512, out.lengthSync());
      var bytes = await out.openRead(0, size).first;
      var info = decoder.startDecode(Uint8List.fromList(bytes));
      if (info != null) {
        b = info.height > image.height || info.width > image.width;
      }
    }
    return b;
  }

  Future<List<int>> downloadImage(Files image, String url) async {
    late Object exception;
    for (var i = 0; i < 3; i++) {
      try {
        final data = await http_invke(_buildDownloadUrl(image),
            proxy: prefenerce.proxy,
            headers: {
              'referer': url,
              'authority': "${_getUserInfo(image.hash)}.hitomi.la",
              'path':
                  '/webp/${this.code}/${_parseLast3HashCode(image.hash)}/${image.hash}.webp',
              'user-agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36 Edg/106.0.1370.47'
            });
        print(
            '下载${image.name} ${image.height}*${image.width} size ${data.length / 1024}');
        return data;
      } catch (e) {
        print(e);
        exception = e;
      }
    }
    throw exception;
  }

  String _buildDownloadUrl(Files image) {
    return "https://${_getUserInfo(image.hash)}.hitomi.la/webp/${this.code}/${_parseLast3HashCode(image.hash)}/${image.hash}.webp";
  }

  String _getUserInfo(String hash) {
    final code = _parseLast3HashCode(hash);
    final userInfo = ['aa', 'ba'];
    var useIndex =
        index - (this.codes.any((element) => element == code) ? 1 : 0);
    return userInfo[useIndex.abs()];
  }

  int _parseLast3HashCode(String hash) {
    return int.parse(String.fromCharCode(hash.codeUnitAt(hash.length - 1)),
                radix: 16) <<
            8 |
        int.parse(hash.substring(hash.length - 3, hash.length - 1), radix: 16);
  }

  @override
  Future<Gallery> fetchGallery(String id, {usePrefence = true}) async {
    Map<String, dynamic> json = await _fetchGalleryJsonById(id);
    var gallery = Gallery.fromJson(json);
    if (usePrefence) {
      final languages = gallery.languages
          ?.where((element) =>
              prefenerce.languages.map((e) => e.name).contains(element.name))
          .toList();
      if (languages?.isNotEmpty == true) {
        languages!.sort((a, b) => prefenerce.languages
            .indexWhere((l) => l.name == a.name)
            .compareTo(
                prefenerce.languages.indexWhere((l) => l.name == b.name)));
        final language = languages.first;
        if (id != language.galleryid) {
          print('select best language ${language.toJson()}');
          json = await _fetchGalleryJsonById(language.galleryid);
          gallery = Gallery.fromJson(json);
        }
      } else if (!prefenerce.languages
          .map((e) => e.name)
          .contains(gallery.language)) {
        throw 'not match the language';
      }
    }
    return gallery;
  }

  @override
  Stream<Gallery> search(List<Tag> args, [int page = 0]) {
    throw UnimplementedError();
  }

  @override
  Stream<Gallery> viewByTag(Tag tag, [int page = 0]) {
    var url = 'https://hitomi.la/${tag.urlEncode()}-all.html';
    throw UnimplementedError();
  }

  @override
  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> restart() {
    // TODO: implement restart
    throw UnimplementedError();
  }
}

class Tag {
  final String type;
  final String name;
  const Tag({this.type = 'tag', required this.name});

  Tag.fromStr(String input)
      : this.type = input.split(":").first,
        this.name = input.split(":").last;

  @override
  String toString() {
    return "{$type:$name}";
  }

  String urlEncode() {
    return "$type/${Uri.encodeComponent(name)}";
  }
}

class Language extends Tag {
  static const all = Language._('all');
  static const japanese = Language._('japanese');
  static const chinese = Language._('chinese');
  static const english = Language._('english');

  const Language._(String name) : super(type: 'language', name: name);
  @override
  String toString() {
    return "$name";
  }

  @override
  String urlEncode() {
    return "index-$name";
  }

  factory Language.fromName(String language) {
    switch (language) {
      case 'japanese':
        return japanese;
      case 'chinese':
        return chinese;
      case 'english':
        return english;
      default:
        return all;
    }
  }
}

class SexTag extends Tag {
  const SexTag._(String sex, String name) : super(type: sex, name: name);

  factory SexTag.fromName(String sex, String name) {
    switch (sex) {
      case 'male':
        return SexTag._(sex, name);
      case 'female':
        return SexTag._(sex, name);
      default:
        throw 'wrong type';
    }
  }

  @override
  String urlEncode() {
    return "tag/$type:${Uri.encodeComponent(name)}";
  }
}

class GalleryType extends Tag {
  static const doujinshi = GalleryType._('doujinshi');
  static const manga = GalleryType._('manga');
  static const artistCG = GalleryType._('artistcg');
  static const gameCG = GalleryType._('gamecg');
  static const anime = GalleryType._('anime');

  const GalleryType._(String name) : super(type: "type", name: name);

  factory GalleryType.fromName(String name) {
    switch (name.toLowerCase()) {
      case "doujinshi":
        return GalleryType.doujinshi;
      case "manga":
        return GalleryType.manga;
      case "artistcg":
        return GalleryType.artistCG;
      case "gamecg":
        return GalleryType.gameCG;
      case "anime":
        return GalleryType.anime;
      default:
        throw 'unknow type';
    }
  }

  @override
  String toString() {
    return name;
  }
}
