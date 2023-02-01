import 'package:hitomi/gallery/language.dart';
import 'package:hitomi/lib.dart';

void main() async {
  final List<Language> languages = [Language.japanese, Language.chinese];
  var config = UserContext('~/', proxy: '127.0.0.1:8389', languages: languages);
  final hitomi = Hitomi.fromPrefenerce(config);
  var ids = await hitomi.findSimilarGalleryBySearch(
      await hitomi.fetchGallery('2452816', usePrefence: false));
  await ids.forEach((element) {
    print(element);
  });
}
