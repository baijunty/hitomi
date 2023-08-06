import 'dart:async';
import 'dart:io';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/lib.dart';
import 'package:hitomi/src/dhash.dart';
import 'package:hitomi/src/gallery_manager.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:test/test.dart';

void main() async {
  test('match', () async {
    print('sdf'.split(';'));
    var config = UserContext(UserConfig(r'/home/bai/ssd/photos',
        proxy: '127.0.0.1:8389',
        languages: ['chinese', 'japanese'],
        maxTasks: 5));
    var fix = GalleryManager(config, null);
    await config.initData();
    var r = await fix.parseCommandAndRun('2426005');
    // .parseArgs('tags --type artist -n simon -t doujinshi -t manga');
    print(r);
  });
}

Future<void> testGalleryInfoDistance() async {
  var config = UserContext(UserConfig(r'/home/bai/ssd/photos',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  var fix = GalleryManager(config, null);
  final result = await fix.listInfo().then((value) =>
      value.fold<Map<GalleryInfo, List<GalleryInfo>>>({}, ((previous, element) {
        final list = previous[element] ?? [];
        list.add(element);
        previous[element] = list;
        return previous;
      })));
  result.entries.where((element) => element.value.length > 1).forEach((entry) {
    var key = entry.key;
    var value = entry.value;
    print('$key and ${value.length}');
    value.forEach((element) {
      final reletion = key.relationToOther(element);
      print('$key and ${element} is $reletion');
    });
  });
}

Future<Gallery?> testGalleryInfo(String name) async {
  var config = UserContext(UserConfig('/home/bai/ssd/photos',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  var gallery =
      GalleryInfo.formDirect(Directory('${config.outPut}/$name'), config);
  await config.initData();
  return await gallery.tryGetGalleryInfo();
}

Future<void> testImageHash() async {
  var hash1 = await imageHash(
      File(r'/home/bai/ssd/photos/三連休は朝まで生ゆきのん。/01.jpg').readAsBytesSync());
  print(hash1);
}

Future<void> testSqlHelper() async {
  var config = UserContext(UserConfig(r'/home/bai/ssd/photos',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  // await config.initData();
  var row =
      await SqliteHelper(config).querySql("select split('1-2-3','-') as t");
  row?.forEach((element) {
    print('${element.keys} is ${element.values}');
  });
}

Future<void> testImageSearch() async {
  var config = UserContext(UserConfig('.',
      proxy: '127.0.0.1:8389',
      languages: ['chinese', 'japanese'],
      maxTasks: 5));
  await config.initData();
  final hitomi = Hitomi.fromPrefenerce(config);
  var ids = await hitomi.findSimilarGalleryBySearch(
      await hitomi.fetchGallery(1333333, usePrefence: false));
  print((await ids.first).item2);
}

Future<void> testImageDownload() async {
  var config = UserConfig('.',
      proxy: '127.0.0.1:8389', languages: ['chinese', 'japanese'], maxTasks: 5);
  var pool = TaskManager(config);
  var task = await pool.addNewTask('45465465489456');
  await Future.delayed(Duration(seconds: 5));
  task?.cancel();
  await Future.delayed(Duration(seconds: 1));
  task?.start();
  await Future.delayed(Duration(seconds: 5));
  task?.cancel();
  task = await pool.addNewTask('2473175');
  await Future.delayed(Duration(seconds: 5));
  task?.cancel();
}
