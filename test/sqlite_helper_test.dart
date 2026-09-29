import 'dart:io';

import 'package:collection/collection.dart';
import 'package:hitomi/gallery/artist.dart';
import 'package:hitomi/gallery/gallery.dart';
import 'package:hitomi/gallery/image.dart';
import 'package:hitomi/gallery/label.dart';
import 'package:hitomi/src/sqlite_helper.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// drift 重构后的回归测试：覆盖建库、自定义函数、事务嵌套、
/// 级联删除、以及旧版本库的迁移链。
void main() {
  late Directory dir;
  late SqliteHelper helper;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hitomi_db_test');
    helper = SqliteHelper(dir.path);
  });

  tearDown(() async {
    await helper.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Image img(String name, {int fileHash = 1234}) => Image(
    hash: 'abc',
    hasavif: 0,
    width: 100,
    name: name,
    height: 200,
    fileHash: fileHash,
  );

  group('fresh database', () {
    test('creates all tables and indexes at schema v16', () async {
      await helper.checkInit();

      expect(await helper.querySql('pragma user_version'), hasLength(1));
      expect(
        (await helper.querySql('pragma user_version')).first.columnAt(0),
        16,
      );

      final tables = (await helper.querySql(
        "select name from sqlite_master where type='table' order by name",
      )).map((r) => r['name']).toList();
      expect(
        tables,
        containsAll(<String>[
          'Tags',
          'Gallery',
          'GalleryExtra',
          'GalleryFile',
          'Tasks',
          'UserLog',
          'GalleryTagRelation',
        ]),
      );

      final indexes = (await helper.querySql(
        "select name from sqlite_master where type='index' and name like 'idx_%' order by name",
      )).map((r) => r['name']).toList();
      expect(indexes, hasLength(6));
    });

    test('checkInit is single-flight (concurrent calls share one open)', () async {
      await Future.wait([
        helper.checkInit(),
        helper.checkInit(),
        helper.checkInit(),
      ]);
      expect(
        (await helper.querySql('pragma user_version')).first.columnAt(0),
        16,
      );
    });

    test('Gallery.path is NOT unique (historical `TEXT Quique` typo)', () async {
      await helper.checkInit();
      // 旧库里 path 没有唯一约束，重构后必须保持一致，否则同名目录的
      // 多个 gallery 会插入失败。
      await helper.excuteSqlAsync(
        'insert into Gallery(id,path,language,title) values(1,?,?,?)',
        ['same.jpg', 'cn', 'a'],
      );
      await helper.excuteSqlAsync(
        'insert into Gallery(id,path,language,title) values(2,?,?,?)',
        ['same.jpg', 'cn', 'b'],
      );
      expect(
        await helper.querySql('select id from Gallery where path=?', ['same.jpg']),
        hasLength(2),
      );
    });
  });

  group('tags', () {
    test('queryOrInsertTagTable inserts, is idempotent, and maps QueryText to -1', () async {
      final first = await helper.queryOrInsertTagTable([
        fromString('female', 'schoolgirl'),
        fromString('artist', 'test_artist'),
        fromString('query', 'not_a_real_tag'),
      ]);
      expect(first.values.where((v) => v > 0), hasLength(2));
      expect(first.values.where((v) => v == -1), hasLength(1));

      // 第二次调用必须复用已有 id，不产生新行。
      final second = await helper.queryOrInsertTagTable([
        fromString('female', 'schoolgirl'),
      ]);
      expect(second.values.single, first.values.firstWhere((v) => v > 0));
      expect(await helper.querySql('select id from Tags'), hasLength(2));
    });

    test('updateTagTable replaces by (type,name) without duplicating', () async {
      await helper.updateTagTable([
        [1, 'tag', 'cat', 'neko', '', null, null],
      ]);
      await helper.updateTagTable([
        [1, 'tag', 'cat', 'inu', '', null, null],
      ]);
      final rows = await helper.querySql(
        'select translate from Tags where type=? and name=?',
        ['tag', 'cat'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['translate'], 'inu');
    });

    test('fetchLabelsFromSql prefers exact matches', () async {
      await helper.updateTagTable([
        [1, 'tag', 'cats', 'cats2', '', null, null],
        [2, 'tag', 'cat', 'catz', '', null, null],
        [3, 'tag', 'category', 'xx', '', null, null],
      ]);
      final hits = await helper.fetchLabelsFromSql('cat');
      expect(hits, isNotEmpty);
      expect(hits.first['name'], 'cat');
    });
  });

  group('custom sql functions', () {
    test('vector_distance / hash_distance / title_fixed are registered', () async {
      // 先建出 Gallery + GalleryExtra 父行，否则 UPDATE 是 no-op。
      await helper.excuteSqlAsync(
        'insert into Gallery(id,path,language,title) values(?,?,?,?)',
        [1, 'p.jpg', 'cn', 't'],
      );
      await helper.excuteSqlAsync('insert into GalleryExtra(gid) values(1)', []);
      await helper.updateGalleryImageEmbedding(1, List<double>.filled(64, 0.5));
      // 两个相同向量的余弦距离为 0。
      final vd = await helper.querySql(
        'select vector_distance(e1.imageEmbedding, e2.imageEmbedding) as d '
        'from GalleryExtra e1, GalleryExtra e2 where e1.gid=? and e2.gid=?',
        [1, 1],
      );
      expect(vd.first.columnAt(0), closeTo(0.0, 1e-9));

      final hd = await helper.querySql('select hash_distance(?, ?) as d', [
        0xFF,
        0xFF,
      ]);
      expect(hd.first.columnAt(0), 0);

      final tf = await helper.querySql('select title_fixed(?, ?) as t', [
        'a/b:c',
        42,
      ]);
      expect(tf.first.columnAt(0), isA<String>());
    });

    test('vector_distance falls back to 100 on bad input', () async {
      final vd = await helper.querySql(
        'select vector_distance(cast(? as blob), cast(? as blob)) as d',
        [
          [1, 2],
          [3, 4, 5],
        ],
      );
      expect(vd.first.columnAt(0), 100.0);
    });
  });

  group('gallery lifecycle', () {
    Future<Gallery> seedGallery() async {
      final gallery = Gallery(
        id: 12345,
        type: 'doujinshi',
        title: 'test_gallery',
        language: 'chinese',
        date: '2024-01-01',
        files: [img('001.jpg')],
        artists: [Artist(artist: 'test_artist')],
      );
      final file = File('${dir.path}/test_gallery');
      file.createSync();
      await helper.insertGallery(gallery, file);
      await helper.insertGalleryFile(gallery, img('001.jpg'), 1234);
      return gallery;
    }

    test('insertGallery + queryGalleryById roundtrip', () async {
      await seedGallery();
      final g = await helper.queryGalleryById(12345);
      expect(g.id, 12345);
      expect(g.title, 'test_gallery');
      expect(g.language, 'chinese');
    });

    test('insertGallery writes Gallery + relation + extra atomically', () async {
      await seedGallery();
      expect(await helper.querySql('select 1 from Gallery where id=?', [12345]), isNotEmpty);
      expect(
        await helper.querySql('select 1 from GalleryExtra where gid=?', [12345]),
        isNotEmpty,
      );
      expect(
        await helper.querySql('select 1 from GalleryTagRelation where gid=?', [12345]),
        isNotEmpty,
      );
    });

    test('deleteGallery removes children first, leaving no orphans', () async {
      await seedGallery();
      await helper.deleteGallery(12345);
      for (final t in ['Gallery', 'GalleryFile', 'GalleryExtra', 'GalleryTagRelation']) {
        final c = await helper.querySql('select count(*) as c from $t');
        expect(c.first.columnAt(0), 0, reason: '$t should be empty');
      }
    });

    test('embedding updates roundtrip as blob', () async {
      await seedGallery();
      await helper.updateGalleryImageEmbedding(12345, List<double>.filled(8, 0.25));
      await helper.updateGalleryStoryDescription(12345, 'hello story');
      await helper.updateGalleryTextEmbedding(12345, List<double>.filled(8, 0.75));

      final row = (await helper.querySql(
        'select imageEmbedding,storyDescription,textEmbedding from GalleryExtra where gid=?',
        [12345],
      )).first;
      expect((row['imageEmbedding'] as List<int>).length, 8 * 8);
      expect(row['storyDescription'], 'hello story');
      expect((row['textEmbedding'] as List<int>).length, 8 * 8);
    });

    test('queryImageHashsByLabel groups fileHash by gid', () async {
      await seedGallery();
      final map = await helper.queryImageHashsByLabel('artist', 'test_artist');
      expect(map[12345], [1234]);
    });
  });

  group('transactions', () {
    test('nested transaction rolls back only to the savepoint', () async {
      await helper.transaction(() async {
        await helper.updateTask(1, 't1', '/tmp/t1', false);
        try {
          await helper.transaction(() async {
            await helper.updateTask(2, 't2', '/tmp/t2', false);
            throw StateError('inner boom');
          });
        } catch (_) {
          // 内层回滚，外层继续。
        }
      });
      final ids = (await helper.querySql('select id from Tasks order by id'))
          .map((r) => r['id'])
          .toList();
      expect(ids, [1]);
    });

    test('outer transaction rollback discards everything', () async {
      try {
        await helper.transaction(() async {
          await helper.updateTask(1, 't1', '/tmp/t1', false);
          await helper.updateTask(2, 't2', '/tmp/t2', false);
          throw StateError('outer boom');
        });
      } catch (_) {}
      expect(await helper.querySql('select id from Tasks'), isEmpty);
    });

    test('excuteSqlMultiParams is atomic across the batch', () async {
      try {
        await helper.excuteSqlMultiParams(
          'insert into Tasks(id,title,path,completed) values(?,?,?,?)',
          [
            [1, 'ok', '/a', 0],
            [2, 'bad', null, 0], // NOT NULL 违反，整批回滚
          ],
        );
        fail('expected a constraint violation');
      } catch (e) {
        expect(e, isA<Object>());
      }
      expect(await helper.querySql('select id from Tasks'), isEmpty);
    });
  });

  group('query helpers', () {
    test('readlData returns the projected column', () async {
      await helper.excuteSqlAsync(
        'insert into Gallery(id,path,language,title) values(?,?,?,?)',
        [7, 'p.jpg', 'cn', 't'],
      );
      expect(await helper.readlData<String>('Gallery', 'path', {'id': 7}), 'p.jpg');
      expect(await helper.readlData<String>('Gallery', 'path', {'id': 999}), isNull);
    });

    test('selectSqlMultiResultAsync keys results by the param list', () async {
      await helper.excuteSqlAsync(
        'insert into Gallery(id,path,language,title) values(?,?,?,?)',
        [7, 'p.jpg', 'cn', 't'],
      );
      final multi = await helper.selectSqlMultiResultAsync(
        'select 1 from Gallery where id = ?',
        [
          [7],
          [99999],
        ],
      );
      // Map<List, ...> 是标识相等，调用方（与旧实现一致）用 collection 的
      // .equals 找自己的那条。
      ResultSet byKey(List<dynamic> key) =>
          multi.entries.firstWhere((e) => e.key.equals(key)).value;
      expect(byKey([7]).length, 1);
      expect(byKey([99999]).length, 0);
    });

    test('querySqlByCursor yields the same rows as querySql', () async {
      await helper.excuteSqlAsync(
        'insert into Gallery(id,path,language,title) values(?,?,?,?)',
        [7, 'p.jpg', 'cn', 't'],
      );
      final stream = await helper.querySqlByCursor('select id from Gallery');
      expect(await stream.map((r) => r['id']).toList(), [7]);
    });

    test('delete() honors the where map', () async {
      await helper.excuteSqlAsync(
        'insert into Gallery(id,path,language,title) values(?,?,?,?)',
        [7, 'p.jpg', 'cn', 't'],
      );
      expect(await helper.delete('Gallery', {'id': 7}), isTrue);
      expect(await helper.querySql('select id from Gallery'), isEmpty);
    });

    test('empty result set is still a usable ResultSet', () async {
      final set = await helper.querySql('select id from Gallery where 0=1');
      expect(set, isEmpty);
      expect(set.toList(), isEmpty);
    });
  });

  group('legacy migration', () {
    test('v13 database upgrades to v16 with data intact', () async {
      final dbFile = '${dir.path}/user.db';
      final raw = sqlite3.open(dbFile);
      raw.execute('PRAGMA foreign_keys=OFF;');
      raw.execute('''
        create table Gallery(
          id integer PRIMARY KEY, path TEXT, language TEXT not null,
          title TEXT not NULL, createDate TEXT, type Text, date INTEGER,
          mark INTEGER default 0, length integer, feature TEXT)''');
      raw.execute('''
        create table UserLog(
          id integer, mark integer, type integer default 0, content Text,
          extension BLOB, PRIMARY KEY(id,type))''');
      raw.execute('''
        create table GalleryFile(
          gid INTEGER, hash TEXT not NULL, name TEXT not NULL, width integer,
          height integer, fileHash integer, PRIMARY KEY(gid,name))''');
      raw.execute('''
        create table Tags(
          id Integer PRIMARY KEY autoincrement, type TEXT NOT NULL,
          name TEXT NOT NULL, translate TEXT NOT NULL, intro TEXT NOT NULL,
          links TEXT, superior TEXT, CONSTRAINT tag UNIQUE (type,name))''');
      raw.execute(
        "insert into Gallery(id,path,language,title,createDate,type,date,mark,length,feature) "
        "values (777,'g777','chinese','老画廊','2020-01-01','doujinshi',111,0,3,'[0.1,0.2]')",
      );
      raw.execute(
        "insert into UserLog(id,mark,type,content,extension) values (5,42,1,'old log',null)",
      );
      raw.execute(
        "insert into GalleryFile(gid,hash,name,width,height,fileHash) values (777,'h1','001.jpg',10,20,999)",
      );
      raw.execute('PRAGMA user_version=13;');
      raw.close();

      await helper.checkInit();

      expect(
        (await helper.querySql('pragma user_version')).first.columnAt(0),
        16,
      );
      // Gallery 数据存活，feature 列已按 15→16 移除。
      final g = await helper.querySql('select id,path,title from Gallery where id=777');
      expect(g.single['title'], '老画廊');
      expect(
        (await helper.querySql(
          "select count(*) as c from pragma_table_info('Gallery') where name='feature'",
        ))
            .first
            .columnAt(0),
        0,
      );
      // UserLog 的 mark 迁移到 value。
      final log = await helper.querySql(
        'select value from UserLog where id=5 and type=1',
      );
      expect(log.single['value'], 42);
      // GalleryFile 存活。
      expect(
        (await helper.querySql('select fileHash from GalleryFile where gid=777'))
            .single['fileHash'],
        999,
      );
      // 迁移后的库可正常读写。
      await helper.insertUserLog(9, 1 << 14, content: 'post-migration');
      expect(
        (await helper.querySql('select count(*) as c from UserLog')).first.columnAt(0),
        2,
      );
    });

    test('a newer schema version is refused, not silently downgraded', () async {
      final dbFile = '${dir.path}/user.db';
      final raw = sqlite3.open(dbFile);
      raw.execute(
        'create table Gallery(id integer PRIMARY KEY, path TEXT, '
        'language TEXT not null, title TEXT not NULL, createDate TEXT, type Text, '
        'date INTEGER, mark INTEGER default 0, length integer)',
      );
      raw.execute('PRAGMA user_version=99;');
      raw.close();

      await expectLater(
        helper.checkInit(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('newer than this build'),
          ),
        ),
      );
    });
  });
}
