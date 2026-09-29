// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translateMeta = const VerificationMeta(
    'translate',
  );
  @override
  late final GeneratedColumn<String> translate = GeneratedColumn<String>(
    'translate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _superiorMeta = const VerificationMeta(
    'superior',
  );
  @override
  late final GeneratedColumn<String> superior = GeneratedColumn<String>(
    'superior',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    translate,
    intro,
    links,
    superior,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('translate')) {
      context.handle(
        _translateMeta,
        translate.isAcceptableOrUnknown(data['translate']!, _translateMeta),
      );
    } else if (isInserting) {
      context.missing(_translateMeta);
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    } else if (isInserting) {
      context.missing(_introMeta);
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    if (data.containsKey('superior')) {
      context.handle(
        _superiorMeta,
        superior.isAcceptableOrUnknown(data['superior']!, _superiorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {type, name},
  ];
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      translate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translate'],
      )!,
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      )!,
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      ),
      superior: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}superior'],
      ),
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final int id;
  final String type;
  final String name;
  final String translate;
  final String intro;
  final String? links;
  final String? superior;
  const TagRow({
    required this.id,
    required this.type,
    required this.name,
    required this.translate,
    required this.intro,
    this.links,
    this.superior,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['translate'] = Variable<String>(translate);
    map['intro'] = Variable<String>(intro);
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String>(links);
    }
    if (!nullToAbsent || superior != null) {
      map['superior'] = Variable<String>(superior);
    }
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      translate: Value(translate),
      intro: Value(intro),
      links: links == null && nullToAbsent
          ? const Value.absent()
          : Value(links),
      superior: superior == null && nullToAbsent
          ? const Value.absent()
          : Value(superior),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      translate: serializer.fromJson<String>(json['translate']),
      intro: serializer.fromJson<String>(json['intro']),
      links: serializer.fromJson<String?>(json['links']),
      superior: serializer.fromJson<String?>(json['superior']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'translate': serializer.toJson<String>(translate),
      'intro': serializer.toJson<String>(intro),
      'links': serializer.toJson<String?>(links),
      'superior': serializer.toJson<String?>(superior),
    };
  }

  TagRow copyWith({
    int? id,
    String? type,
    String? name,
    String? translate,
    String? intro,
    Value<String?> links = const Value.absent(),
    Value<String?> superior = const Value.absent(),
  }) => TagRow(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    translate: translate ?? this.translate,
    intro: intro ?? this.intro,
    links: links.present ? links.value : this.links,
    superior: superior.present ? superior.value : this.superior,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      translate: data.translate.present ? data.translate.value : this.translate,
      intro: data.intro.present ? data.intro.value : this.intro,
      links: data.links.present ? data.links.value : this.links,
      superior: data.superior.present ? data.superior.value : this.superior,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('translate: $translate, ')
          ..write('intro: $intro, ')
          ..write('links: $links, ')
          ..write('superior: $superior')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, name, translate, intro, links, superior);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.translate == this.translate &&
          other.intro == this.intro &&
          other.links == this.links &&
          other.superior == this.superior);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String> translate;
  final Value<String> intro;
  final Value<String?> links;
  final Value<String?> superior;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.translate = const Value.absent(),
    this.intro = const Value.absent(),
    this.links = const Value.absent(),
    this.superior = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String name,
    required String translate,
    required String intro,
    this.links = const Value.absent(),
    this.superior = const Value.absent(),
  }) : type = Value(type),
       name = Value(name),
       translate = Value(translate),
       intro = Value(intro);
  static Insertable<TagRow> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? translate,
    Expression<String>? intro,
    Expression<String>? links,
    Expression<String>? superior,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (translate != null) 'translate': translate,
      if (intro != null) 'intro': intro,
      if (links != null) 'links': links,
      if (superior != null) 'superior': superior,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String>? name,
    Value<String>? translate,
    Value<String>? intro,
    Value<String?>? links,
    Value<String?>? superior,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      translate: translate ?? this.translate,
      intro: intro ?? this.intro,
      links: links ?? this.links,
      superior: superior ?? this.superior,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (translate.present) {
      map['translate'] = Variable<String>(translate.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (superior.present) {
      map['superior'] = Variable<String>(superior.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('translate: $translate, ')
          ..write('intro: $intro, ')
          ..write('links: $links, ')
          ..write('superior: $superior')
          ..write(')'))
        .toString();
  }
}

class $GalleryTable extends Gallery with TableInfo<$GalleryTable, GalleryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createDateMeta = const VerificationMeta(
    'createDate',
  );
  @override
  late final GeneratedColumn<String> createDate = GeneratedColumn<String>(
    'createDate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _markMeta = const VerificationMeta('mark');
  @override
  late final GeneratedColumn<int> mark = GeneratedColumn<int>(
    'mark',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<int> length = GeneratedColumn<int>(
    'length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    language,
    title,
    createDate,
    type,
    date,
    mark,
    length,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Gallery';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('createDate')) {
      context.handle(
        _createDateMeta,
        createDate.isAcceptableOrUnknown(data['createDate']!, _createDateMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('mark')) {
      context.handle(
        _markMeta,
        mark.isAcceptableOrUnknown(data['mark']!, _markMeta),
      );
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GalleryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}createDate'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      ),
      mark: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mark'],
      )!,
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length'],
      ),
    );
  }

  @override
  $GalleryTable createAlias(String alias) {
    return $GalleryTable(attachedDatabase, alias);
  }
}

class GalleryRow extends DataClass implements Insertable<GalleryRow> {
  final int id;
  final String? path;
  final String language;
  final String title;
  final String? createDate;
  final String? type;
  final int? date;
  final int mark;
  final int? length;
  const GalleryRow({
    required this.id,
    this.path,
    required this.language,
    required this.title,
    this.createDate,
    this.type,
    this.date,
    required this.mark,
    this.length,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    map['language'] = Variable<String>(language);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || createDate != null) {
      map['createDate'] = Variable<String>(createDate);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<String>(type);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<int>(date);
    }
    map['mark'] = Variable<int>(mark);
    if (!nullToAbsent || length != null) {
      map['length'] = Variable<int>(length);
    }
    return map;
  }

  GalleryCompanion toCompanion(bool nullToAbsent) {
    return GalleryCompanion(
      id: Value(id),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      language: Value(language),
      title: Value(title),
      createDate: createDate == null && nullToAbsent
          ? const Value.absent()
          : Value(createDate),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      mark: Value(mark),
      length: length == null && nullToAbsent
          ? const Value.absent()
          : Value(length),
    );
  }

  factory GalleryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String?>(json['path']),
      language: serializer.fromJson<String>(json['language']),
      title: serializer.fromJson<String>(json['title']),
      createDate: serializer.fromJson<String?>(json['createDate']),
      type: serializer.fromJson<String?>(json['type']),
      date: serializer.fromJson<int?>(json['date']),
      mark: serializer.fromJson<int>(json['mark']),
      length: serializer.fromJson<int?>(json['length']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String?>(path),
      'language': serializer.toJson<String>(language),
      'title': serializer.toJson<String>(title),
      'createDate': serializer.toJson<String?>(createDate),
      'type': serializer.toJson<String?>(type),
      'date': serializer.toJson<int?>(date),
      'mark': serializer.toJson<int>(mark),
      'length': serializer.toJson<int?>(length),
    };
  }

  GalleryRow copyWith({
    int? id,
    Value<String?> path = const Value.absent(),
    String? language,
    String? title,
    Value<String?> createDate = const Value.absent(),
    Value<String?> type = const Value.absent(),
    Value<int?> date = const Value.absent(),
    int? mark,
    Value<int?> length = const Value.absent(),
  }) => GalleryRow(
    id: id ?? this.id,
    path: path.present ? path.value : this.path,
    language: language ?? this.language,
    title: title ?? this.title,
    createDate: createDate.present ? createDate.value : this.createDate,
    type: type.present ? type.value : this.type,
    date: date.present ? date.value : this.date,
    mark: mark ?? this.mark,
    length: length.present ? length.value : this.length,
  );
  GalleryRow copyWithCompanion(GalleryCompanion data) {
    return GalleryRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      language: data.language.present ? data.language.value : this.language,
      title: data.title.present ? data.title.value : this.title,
      createDate: data.createDate.present
          ? data.createDate.value
          : this.createDate,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
      mark: data.mark.present ? data.mark.value : this.mark,
      length: data.length.present ? data.length.value : this.length,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('createDate: $createDate, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('mark: $mark, ')
          ..write('length: $length')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    path,
    language,
    title,
    createDate,
    type,
    date,
    mark,
    length,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.language == this.language &&
          other.title == this.title &&
          other.createDate == this.createDate &&
          other.type == this.type &&
          other.date == this.date &&
          other.mark == this.mark &&
          other.length == this.length);
}

class GalleryCompanion extends UpdateCompanion<GalleryRow> {
  final Value<int> id;
  final Value<String?> path;
  final Value<String> language;
  final Value<String> title;
  final Value<String?> createDate;
  final Value<String?> type;
  final Value<int?> date;
  final Value<int> mark;
  final Value<int?> length;
  const GalleryCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.language = const Value.absent(),
    this.title = const Value.absent(),
    this.createDate = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.mark = const Value.absent(),
    this.length = const Value.absent(),
  });
  GalleryCompanion.insert({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    required String language,
    required String title,
    this.createDate = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.mark = const Value.absent(),
    this.length = const Value.absent(),
  }) : language = Value(language),
       title = Value(title);
  static Insertable<GalleryRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? language,
    Expression<String>? title,
    Expression<String>? createDate,
    Expression<String>? type,
    Expression<int>? date,
    Expression<int>? mark,
    Expression<int>? length,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (language != null) 'language': language,
      if (title != null) 'title': title,
      if (createDate != null) 'createDate': createDate,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
      if (mark != null) 'mark': mark,
      if (length != null) 'length': length,
    });
  }

  GalleryCompanion copyWith({
    Value<int>? id,
    Value<String?>? path,
    Value<String>? language,
    Value<String>? title,
    Value<String?>? createDate,
    Value<String?>? type,
    Value<int?>? date,
    Value<int>? mark,
    Value<int?>? length,
  }) {
    return GalleryCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      language: language ?? this.language,
      title: title ?? this.title,
      createDate: createDate ?? this.createDate,
      type: type ?? this.type,
      date: date ?? this.date,
      mark: mark ?? this.mark,
      length: length ?? this.length,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createDate.present) {
      map['createDate'] = Variable<String>(createDate.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (mark.present) {
      map['mark'] = Variable<int>(mark.value);
    }
    if (length.present) {
      map['length'] = Variable<int>(length.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('language: $language, ')
          ..write('title: $title, ')
          ..write('createDate: $createDate, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('mark: $mark, ')
          ..write('length: $length')
          ..write(')'))
        .toString();
  }
}

class $GalleryExtraTable extends GalleryExtra
    with TableInfo<$GalleryExtraTable, GalleryExtraRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryExtraTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES Gallery (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _imageEmbeddingMeta = const VerificationMeta(
    'imageEmbedding',
  );
  @override
  late final GeneratedColumn<Uint8List> imageEmbedding =
      GeneratedColumn<Uint8List>(
        'imageEmbedding',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _storyDescriptionMeta = const VerificationMeta(
    'storyDescription',
  );
  @override
  late final GeneratedColumn<String> storyDescription = GeneratedColumn<String>(
    'storyDescription',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textEmbeddingMeta = const VerificationMeta(
    'textEmbedding',
  );
  @override
  late final GeneratedColumn<Uint8List> textEmbedding =
      GeneratedColumn<Uint8List>(
        'textEmbedding',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    gid,
    imageEmbedding,
    storyDescription,
    textEmbedding,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'GalleryExtra';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryExtraRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('imageEmbedding')) {
      context.handle(
        _imageEmbeddingMeta,
        imageEmbedding.isAcceptableOrUnknown(
          data['imageEmbedding']!,
          _imageEmbeddingMeta,
        ),
      );
    }
    if (data.containsKey('storyDescription')) {
      context.handle(
        _storyDescriptionMeta,
        storyDescription.isAcceptableOrUnknown(
          data['storyDescription']!,
          _storyDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('textEmbedding')) {
      context.handle(
        _textEmbeddingMeta,
        textEmbedding.isAcceptableOrUnknown(
          data['textEmbedding']!,
          _textEmbeddingMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {gid},
  ];
  @override
  GalleryExtraRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryExtraRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      )!,
      imageEmbedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}imageEmbedding'],
      ),
      storyDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storyDescription'],
      ),
      textEmbedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}textEmbedding'],
      ),
    );
  }

  @override
  $GalleryExtraTable createAlias(String alias) {
    return $GalleryExtraTable(attachedDatabase, alias);
  }
}

class GalleryExtraRow extends DataClass implements Insertable<GalleryExtraRow> {
  final int id;
  final int gid;
  final Uint8List? imageEmbedding;
  final String? storyDescription;
  final Uint8List? textEmbedding;
  const GalleryExtraRow({
    required this.id,
    required this.gid,
    this.imageEmbedding,
    this.storyDescription,
    this.textEmbedding,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['gid'] = Variable<int>(gid);
    if (!nullToAbsent || imageEmbedding != null) {
      map['imageEmbedding'] = Variable<Uint8List>(imageEmbedding);
    }
    if (!nullToAbsent || storyDescription != null) {
      map['storyDescription'] = Variable<String>(storyDescription);
    }
    if (!nullToAbsent || textEmbedding != null) {
      map['textEmbedding'] = Variable<Uint8List>(textEmbedding);
    }
    return map;
  }

  GalleryExtraCompanion toCompanion(bool nullToAbsent) {
    return GalleryExtraCompanion(
      id: Value(id),
      gid: Value(gid),
      imageEmbedding: imageEmbedding == null && nullToAbsent
          ? const Value.absent()
          : Value(imageEmbedding),
      storyDescription: storyDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(storyDescription),
      textEmbedding: textEmbedding == null && nullToAbsent
          ? const Value.absent()
          : Value(textEmbedding),
    );
  }

  factory GalleryExtraRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryExtraRow(
      id: serializer.fromJson<int>(json['id']),
      gid: serializer.fromJson<int>(json['gid']),
      imageEmbedding: serializer.fromJson<Uint8List?>(json['imageEmbedding']),
      storyDescription: serializer.fromJson<String?>(json['storyDescription']),
      textEmbedding: serializer.fromJson<Uint8List?>(json['textEmbedding']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'gid': serializer.toJson<int>(gid),
      'imageEmbedding': serializer.toJson<Uint8List?>(imageEmbedding),
      'storyDescription': serializer.toJson<String?>(storyDescription),
      'textEmbedding': serializer.toJson<Uint8List?>(textEmbedding),
    };
  }

  GalleryExtraRow copyWith({
    int? id,
    int? gid,
    Value<Uint8List?> imageEmbedding = const Value.absent(),
    Value<String?> storyDescription = const Value.absent(),
    Value<Uint8List?> textEmbedding = const Value.absent(),
  }) => GalleryExtraRow(
    id: id ?? this.id,
    gid: gid ?? this.gid,
    imageEmbedding: imageEmbedding.present
        ? imageEmbedding.value
        : this.imageEmbedding,
    storyDescription: storyDescription.present
        ? storyDescription.value
        : this.storyDescription,
    textEmbedding: textEmbedding.present
        ? textEmbedding.value
        : this.textEmbedding,
  );
  GalleryExtraRow copyWithCompanion(GalleryExtraCompanion data) {
    return GalleryExtraRow(
      id: data.id.present ? data.id.value : this.id,
      gid: data.gid.present ? data.gid.value : this.gid,
      imageEmbedding: data.imageEmbedding.present
          ? data.imageEmbedding.value
          : this.imageEmbedding,
      storyDescription: data.storyDescription.present
          ? data.storyDescription.value
          : this.storyDescription,
      textEmbedding: data.textEmbedding.present
          ? data.textEmbedding.value
          : this.textEmbedding,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryExtraRow(')
          ..write('id: $id, ')
          ..write('gid: $gid, ')
          ..write('imageEmbedding: $imageEmbedding, ')
          ..write('storyDescription: $storyDescription, ')
          ..write('textEmbedding: $textEmbedding')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    gid,
    $driftBlobEquality.hash(imageEmbedding),
    storyDescription,
    $driftBlobEquality.hash(textEmbedding),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryExtraRow &&
          other.id == this.id &&
          other.gid == this.gid &&
          $driftBlobEquality.equals(
            other.imageEmbedding,
            this.imageEmbedding,
          ) &&
          other.storyDescription == this.storyDescription &&
          $driftBlobEquality.equals(other.textEmbedding, this.textEmbedding));
}

class GalleryExtraCompanion extends UpdateCompanion<GalleryExtraRow> {
  final Value<int> id;
  final Value<int> gid;
  final Value<Uint8List?> imageEmbedding;
  final Value<String?> storyDescription;
  final Value<Uint8List?> textEmbedding;
  const GalleryExtraCompanion({
    this.id = const Value.absent(),
    this.gid = const Value.absent(),
    this.imageEmbedding = const Value.absent(),
    this.storyDescription = const Value.absent(),
    this.textEmbedding = const Value.absent(),
  });
  GalleryExtraCompanion.insert({
    this.id = const Value.absent(),
    required int gid,
    this.imageEmbedding = const Value.absent(),
    this.storyDescription = const Value.absent(),
    this.textEmbedding = const Value.absent(),
  }) : gid = Value(gid);
  static Insertable<GalleryExtraRow> custom({
    Expression<int>? id,
    Expression<int>? gid,
    Expression<Uint8List>? imageEmbedding,
    Expression<String>? storyDescription,
    Expression<Uint8List>? textEmbedding,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gid != null) 'gid': gid,
      if (imageEmbedding != null) 'imageEmbedding': imageEmbedding,
      if (storyDescription != null) 'storyDescription': storyDescription,
      if (textEmbedding != null) 'textEmbedding': textEmbedding,
    });
  }

  GalleryExtraCompanion copyWith({
    Value<int>? id,
    Value<int>? gid,
    Value<Uint8List?>? imageEmbedding,
    Value<String?>? storyDescription,
    Value<Uint8List?>? textEmbedding,
  }) {
    return GalleryExtraCompanion(
      id: id ?? this.id,
      gid: gid ?? this.gid,
      imageEmbedding: imageEmbedding ?? this.imageEmbedding,
      storyDescription: storyDescription ?? this.storyDescription,
      textEmbedding: textEmbedding ?? this.textEmbedding,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (imageEmbedding.present) {
      map['imageEmbedding'] = Variable<Uint8List>(imageEmbedding.value);
    }
    if (storyDescription.present) {
      map['storyDescription'] = Variable<String>(storyDescription.value);
    }
    if (textEmbedding.present) {
      map['textEmbedding'] = Variable<Uint8List>(textEmbedding.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryExtraCompanion(')
          ..write('id: $id, ')
          ..write('gid: $gid, ')
          ..write('imageEmbedding: $imageEmbedding, ')
          ..write('storyDescription: $storyDescription, ')
          ..write('textEmbedding: $textEmbedding')
          ..write(')'))
        .toString();
  }
}

class $GalleryFileTable extends GalleryFile
    with TableInfo<$GalleryFileTable, GalleryFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryFileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES Gallery (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<int> fileHash = GeneratedColumn<int>(
    'fileHash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gid,
    hash,
    name,
    width,
    height,
    fileHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'GalleryFile';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('fileHash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['fileHash']!, _fileHashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid, name};
  @override
  GalleryFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryFileRow(
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      ),
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fileHash'],
      ),
    );
  }

  @override
  $GalleryFileTable createAlias(String alias) {
    return $GalleryFileTable(attachedDatabase, alias);
  }
}

class GalleryFileRow extends DataClass implements Insertable<GalleryFileRow> {
  final int? gid;
  final String hash;
  final String name;
  final int? width;
  final int? height;
  final int? fileHash;
  const GalleryFileRow({
    this.gid,
    required this.hash,
    required this.name,
    this.width,
    this.height,
    this.fileHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || gid != null) {
      map['gid'] = Variable<int>(gid);
    }
    map['hash'] = Variable<String>(hash);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || fileHash != null) {
      map['fileHash'] = Variable<int>(fileHash);
    }
    return map;
  }

  GalleryFileCompanion toCompanion(bool nullToAbsent) {
    return GalleryFileCompanion(
      gid: gid == null && nullToAbsent ? const Value.absent() : Value(gid),
      hash: Value(hash),
      name: Value(name),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      fileHash: fileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(fileHash),
    );
  }

  factory GalleryFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryFileRow(
      gid: serializer.fromJson<int?>(json['gid']),
      hash: serializer.fromJson<String>(json['hash']),
      name: serializer.fromJson<String>(json['name']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      fileHash: serializer.fromJson<int?>(json['fileHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int?>(gid),
      'hash': serializer.toJson<String>(hash),
      'name': serializer.toJson<String>(name),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'fileHash': serializer.toJson<int?>(fileHash),
    };
  }

  GalleryFileRow copyWith({
    Value<int?> gid = const Value.absent(),
    String? hash,
    String? name,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> fileHash = const Value.absent(),
  }) => GalleryFileRow(
    gid: gid.present ? gid.value : this.gid,
    hash: hash ?? this.hash,
    name: name ?? this.name,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    fileHash: fileHash.present ? fileHash.value : this.fileHash,
  );
  GalleryFileRow copyWithCompanion(GalleryFileCompanion data) {
    return GalleryFileRow(
      gid: data.gid.present ? data.gid.value : this.gid,
      hash: data.hash.present ? data.hash.value : this.hash,
      name: data.name.present ? data.name.value : this.name,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryFileRow(')
          ..write('gid: $gid, ')
          ..write('hash: $hash, ')
          ..write('name: $name, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fileHash: $fileHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gid, hash, name, width, height, fileHash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryFileRow &&
          other.gid == this.gid &&
          other.hash == this.hash &&
          other.name == this.name &&
          other.width == this.width &&
          other.height == this.height &&
          other.fileHash == this.fileHash);
}

class GalleryFileCompanion extends UpdateCompanion<GalleryFileRow> {
  final Value<int?> gid;
  final Value<String> hash;
  final Value<String> name;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> fileHash;
  final Value<int> rowid;
  const GalleryFileCompanion({
    this.gid = const Value.absent(),
    this.hash = const Value.absent(),
    this.name = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GalleryFileCompanion.insert({
    this.gid = const Value.absent(),
    required String hash,
    required String name,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : hash = Value(hash),
       name = Value(name);
  static Insertable<GalleryFileRow> custom({
    Expression<int>? gid,
    Expression<String>? hash,
    Expression<String>? name,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? fileHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (hash != null) 'hash': hash,
      if (name != null) 'name': name,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileHash != null) 'fileHash': fileHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GalleryFileCompanion copyWith({
    Value<int?>? gid,
    Value<String>? hash,
    Value<String>? name,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? fileHash,
    Value<int>? rowid,
  }) {
    return GalleryFileCompanion(
      gid: gid ?? this.gid,
      hash: hash ?? this.hash,
      name: name ?? this.name,
      width: width ?? this.width,
      height: height ?? this.height,
      fileHash: fileHash ?? this.fileHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (fileHash.present) {
      map['fileHash'] = Variable<int>(fileHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryFileCompanion(')
          ..write('gid: $gid, ')
          ..write('hash: $hash, ')
          ..write('name: $name, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('fileHash: $fileHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, path, completed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'Tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final int id;
  final String title;
  final String path;
  final bool completed;
  const TaskRow({
    required this.id,
    required this.title,
    required this.path,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['path'] = Variable<String>(path);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      path: Value(path),
      completed: Value(completed),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      path: serializer.fromJson<String>(json['path']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'path': serializer.toJson<String>(path),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  TaskRow copyWith({int? id, String? title, String? path, bool? completed}) =>
      TaskRow(
        id: id ?? this.id,
        title: title ?? this.title,
        path: path ?? this.path,
        completed: completed ?? this.completed,
      );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      path: data.path.present ? data.path.value : this.path,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('path: $path, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, path, completed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.path == this.path &&
          other.completed == this.completed);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> path;
  final Value<bool> completed;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.path = const Value.absent(),
    this.completed = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String path,
    this.completed = const Value.absent(),
  }) : title = Value(title),
       path = Value(path);
  static Insertable<TaskRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? path,
    Expression<bool>? completed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (path != null) 'path': path,
      if (completed != null) 'completed': completed,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? path,
    Value<bool>? completed,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      completed: completed ?? this.completed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('path: $path, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }
}

class $UserLogTable extends UserLog with TableInfo<$UserLogTable, UserLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extensionMeta = const VerificationMeta(
    'extension',
  );
  @override
  late final GeneratedColumn<Uint8List> extension = GeneratedColumn<Uint8List>(
    'extension',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    value,
    type,
    content,
    date,
    extension,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'UserLog';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('extension')) {
      context.handle(
        _extensionMeta,
        extension.isAcceptableOrUnknown(data['extension']!, _extensionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, type};
  @override
  UserLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      ),
      extension: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}extension'],
      ),
    );
  }

  @override
  $UserLogTable createAlias(String alias) {
    return $UserLogTable(attachedDatabase, alias);
  }
}

class UserLogRow extends DataClass implements Insertable<UserLogRow> {
  final int id;
  final int? value;
  final int type;
  final String? content;
  final int? date;
  final Uint8List? extension;
  const UserLogRow({
    required this.id,
    this.value,
    required this.type,
    this.content,
    this.date,
    this.extension,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<int>(value);
    }
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<int>(date);
    }
    if (!nullToAbsent || extension != null) {
      map['extension'] = Variable<Uint8List>(extension);
    }
    return map;
  }

  UserLogCompanion toCompanion(bool nullToAbsent) {
    return UserLogCompanion(
      id: Value(id),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      type: Value(type),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      extension: extension == null && nullToAbsent
          ? const Value.absent()
          : Value(extension),
    );
  }

  factory UserLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserLogRow(
      id: serializer.fromJson<int>(json['id']),
      value: serializer.fromJson<int?>(json['value']),
      type: serializer.fromJson<int>(json['type']),
      content: serializer.fromJson<String?>(json['content']),
      date: serializer.fromJson<int?>(json['date']),
      extension: serializer.fromJson<Uint8List?>(json['extension']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'value': serializer.toJson<int?>(value),
      'type': serializer.toJson<int>(type),
      'content': serializer.toJson<String?>(content),
      'date': serializer.toJson<int?>(date),
      'extension': serializer.toJson<Uint8List?>(extension),
    };
  }

  UserLogRow copyWith({
    int? id,
    Value<int?> value = const Value.absent(),
    int? type,
    Value<String?> content = const Value.absent(),
    Value<int?> date = const Value.absent(),
    Value<Uint8List?> extension = const Value.absent(),
  }) => UserLogRow(
    id: id ?? this.id,
    value: value.present ? value.value : this.value,
    type: type ?? this.type,
    content: content.present ? content.value : this.content,
    date: date.present ? date.value : this.date,
    extension: extension.present ? extension.value : this.extension,
  );
  UserLogRow copyWithCompanion(UserLogCompanion data) {
    return UserLogRow(
      id: data.id.present ? data.id.value : this.id,
      value: data.value.present ? data.value.value : this.value,
      type: data.type.present ? data.type.value : this.type,
      content: data.content.present ? data.content.value : this.content,
      date: data.date.present ? data.date.value : this.date,
      extension: data.extension.present ? data.extension.value : this.extension,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserLogRow(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('date: $date, ')
          ..write('extension: $extension')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    value,
    type,
    content,
    date,
    $driftBlobEquality.hash(extension),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserLogRow &&
          other.id == this.id &&
          other.value == this.value &&
          other.type == this.type &&
          other.content == this.content &&
          other.date == this.date &&
          $driftBlobEquality.equals(other.extension, this.extension));
}

class UserLogCompanion extends UpdateCompanion<UserLogRow> {
  final Value<int> id;
  final Value<int?> value;
  final Value<int> type;
  final Value<String?> content;
  final Value<int?> date;
  final Value<Uint8List?> extension;
  final Value<int> rowid;
  const UserLogCompanion({
    this.id = const Value.absent(),
    this.value = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.date = const Value.absent(),
    this.extension = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserLogCompanion.insert({
    required int id,
    this.value = const Value.absent(),
    this.type = const Value.absent(),
    this.content = const Value.absent(),
    this.date = const Value.absent(),
    this.extension = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<UserLogRow> custom({
    Expression<int>? id,
    Expression<int>? value,
    Expression<int>? type,
    Expression<String>? content,
    Expression<int>? date,
    Expression<Uint8List>? extension,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (value != null) 'value': value,
      if (type != null) 'type': type,
      if (content != null) 'content': content,
      if (date != null) 'date': date,
      if (extension != null) 'extension': extension,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserLogCompanion copyWith({
    Value<int>? id,
    Value<int?>? value,
    Value<int>? type,
    Value<String?>? content,
    Value<int?>? date,
    Value<Uint8List?>? extension,
    Value<int>? rowid,
  }) {
    return UserLogCompanion(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      content: content ?? this.content,
      date: date ?? this.date,
      extension: extension ?? this.extension,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (extension.present) {
      map['extension'] = Variable<Uint8List>(extension.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserLogCompanion(')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('type: $type, ')
          ..write('content: $content, ')
          ..write('date: $date, ')
          ..write('extension: $extension, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GalleryTagRelationTable extends GalleryTagRelation
    with TableInfo<$GalleryTagRelationTable, GalleryTagRelationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryTagRelationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
    'gid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES Gallery (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tidMeta = const VerificationMeta('tid');
  @override
  late final GeneratedColumn<int> tid = GeneratedColumn<int>(
    'tid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES Tags (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [gid, tid, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'GalleryTagRelation';
  @override
  VerificationContext validateIntegrity(
    Insertable<GalleryTagRelationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
        _gidMeta,
        gid.isAcceptableOrUnknown(data['gid']!, _gidMeta),
      );
    }
    if (data.containsKey('tid')) {
      context.handle(
        _tidMeta,
        tid.isAcceptableOrUnknown(data['tid']!, _tidMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid, tid};
  @override
  GalleryTagRelationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryTagRelationRow(
      gid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gid'],
      ),
      tid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tid'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      ),
    );
  }

  @override
  $GalleryTagRelationTable createAlias(String alias) {
    return $GalleryTagRelationTable(attachedDatabase, alias);
  }
}

class GalleryTagRelationRow extends DataClass
    implements Insertable<GalleryTagRelationRow> {
  final int? gid;
  final int? tid;
  final int? type;
  const GalleryTagRelationRow({this.gid, this.tid, this.type});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || gid != null) {
      map['gid'] = Variable<int>(gid);
    }
    if (!nullToAbsent || tid != null) {
      map['tid'] = Variable<int>(tid);
    }
    if (!nullToAbsent || type != null) {
      map['type'] = Variable<int>(type);
    }
    return map;
  }

  GalleryTagRelationCompanion toCompanion(bool nullToAbsent) {
    return GalleryTagRelationCompanion(
      gid: gid == null && nullToAbsent ? const Value.absent() : Value(gid),
      tid: tid == null && nullToAbsent ? const Value.absent() : Value(tid),
      type: type == null && nullToAbsent ? const Value.absent() : Value(type),
    );
  }

  factory GalleryTagRelationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryTagRelationRow(
      gid: serializer.fromJson<int?>(json['gid']),
      tid: serializer.fromJson<int?>(json['tid']),
      type: serializer.fromJson<int?>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int?>(gid),
      'tid': serializer.toJson<int?>(tid),
      'type': serializer.toJson<int?>(type),
    };
  }

  GalleryTagRelationRow copyWith({
    Value<int?> gid = const Value.absent(),
    Value<int?> tid = const Value.absent(),
    Value<int?> type = const Value.absent(),
  }) => GalleryTagRelationRow(
    gid: gid.present ? gid.value : this.gid,
    tid: tid.present ? tid.value : this.tid,
    type: type.present ? type.value : this.type,
  );
  GalleryTagRelationRow copyWithCompanion(GalleryTagRelationCompanion data) {
    return GalleryTagRelationRow(
      gid: data.gid.present ? data.gid.value : this.gid,
      tid: data.tid.present ? data.tid.value : this.tid,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GalleryTagRelationRow(')
          ..write('gid: $gid, ')
          ..write('tid: $tid, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gid, tid, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryTagRelationRow &&
          other.gid == this.gid &&
          other.tid == this.tid &&
          other.type == this.type);
}

class GalleryTagRelationCompanion
    extends UpdateCompanion<GalleryTagRelationRow> {
  final Value<int?> gid;
  final Value<int?> tid;
  final Value<int?> type;
  final Value<int> rowid;
  const GalleryTagRelationCompanion({
    this.gid = const Value.absent(),
    this.tid = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GalleryTagRelationCompanion.insert({
    this.gid = const Value.absent(),
    this.tid = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<GalleryTagRelationRow> custom({
    Expression<int>? gid,
    Expression<int>? tid,
    Expression<int>? type,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (tid != null) 'tid': tid,
      if (type != null) 'type': type,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GalleryTagRelationCompanion copyWith({
    Value<int?>? gid,
    Value<int?>? tid,
    Value<int?>? type,
    Value<int>? rowid,
  }) {
    return GalleryTagRelationCompanion(
      gid: gid ?? this.gid,
      tid: tid ?? this.tid,
      type: type ?? this.type,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (tid.present) {
      map['tid'] = Variable<int>(tid.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryTagRelationCompanion(')
          ..write('gid: $gid, ')
          ..write('tid: $tid, ')
          ..write('type: $type, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HitomiDatabase extends GeneratedDatabase {
  _$HitomiDatabase(QueryExecutor e) : super(e);
  $HitomiDatabaseManager get managers => $HitomiDatabaseManager(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $GalleryTable gallery = $GalleryTable(this);
  late final $GalleryExtraTable galleryExtra = $GalleryExtraTable(this);
  late final $GalleryFileTable galleryFile = $GalleryFileTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $UserLogTable userLog = $UserLogTable(this);
  late final $GalleryTagRelationTable galleryTagRelation =
      $GalleryTagRelationTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tags,
    gallery,
    galleryExtra,
    galleryFile,
    tasks,
    userLog,
    galleryTagRelation,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'Gallery',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('GalleryExtra', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'Gallery',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('GalleryFile', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'Gallery',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('GalleryTagRelation', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String type,
  required String name,
  required String translate,
  required String intro,
  Value<String?> links,
  Value<String?> superior,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> type,
  Value<String> name,
  Value<String> translate,
  Value<String> intro,
  Value<String?> links,
  Value<String?> superior,
});

final class $$TagsTableReferences
    extends BaseReferences<_$HitomiDatabase, $TagsTable, TagRow> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $GalleryTagRelationTable,
    List<GalleryTagRelationRow>
  >
  _galleryTagRelationRefsTable(_$HitomiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.galleryTagRelation,
        aliasName: 'Tags__id__GalleryTagRelation__tid',
      );

  $$GalleryTagRelationTableProcessedTableManager get galleryTagRelationRefs {
    final manager = $$GalleryTagRelationTableTableManager(
      $_db,
      $_db.galleryTagRelation,
    ).filter((f) => f.tid.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _galleryTagRelationRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$HitomiDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translate => $composableBuilder(
    column: $table.translate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get superior => $composableBuilder(
    column: $table.superior,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> galleryTagRelationRefs(
    Expression<bool> Function($$GalleryTagRelationTableFilterComposer f) f,
  ) {
    final $$GalleryTagRelationTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.galleryTagRelation,
      getReferencedColumn: (t) => t.tid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTagRelationTableFilterComposer(
            $db: $db,
            $table: $db.galleryTagRelation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer
    extends Composer<_$HitomiDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translate => $composableBuilder(
    column: $table.translate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get superior => $composableBuilder(
    column: $table.superior,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$HitomiDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get translate =>
      $composableBuilder(column: $table.translate, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get links =>
      $composableBuilder(column: $table.links, builder: (column) => column);

  GeneratedColumn<String> get superior =>
      $composableBuilder(column: $table.superior, builder: (column) => column);

  Expression<T> galleryTagRelationRefs<T extends Object>(
    Expression<T> Function($$GalleryTagRelationTableAnnotationComposer a) f,
  ) {
    final $$GalleryTagRelationTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.galleryTagRelation,
          getReferencedColumn: (t) => t.tid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GalleryTagRelationTableAnnotationComposer(
                $db: $db,
                $table: $db.galleryTagRelation,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$HitomiDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, $$TagsTableReferences),
          TagRow,
          PrefetchHooks Function({bool galleryTagRelationRefs})
        > {
  $$TagsTableTableManager(_$HitomiDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> translate = const Value.absent(),
                Value<String> intro = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<String?> superior = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                type: type,
                name: name,
                translate: translate,
                intro: intro,
                links: links,
                superior: superior,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required String name,
                required String translate,
                required String intro,
                Value<String?> links = const Value.absent(),
                Value<String?> superior = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                type: type,
                name: name,
                translate: translate,
                intro: intro,
                links: links,
                superior: superior,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, TagRow>(table),
                  $$TagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({galleryTagRelationRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (galleryTagRelationRefs) db.galleryTagRelation,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (galleryTagRelationRefs)
                    await $_getPrefetchedData<
                      TagRow,
                      $TagsTable,
                      GalleryTagRelationRow
                    >(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._galleryTagRelationRefsTable(db),
                      managerFromTypedResult: (p0) => $$TagsTableReferences(
                        db,
                        table,
                        p0,
                      ).galleryTagRelationRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tid == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$HitomiDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, $$TagsTableReferences),
      TagRow,
      PrefetchHooks Function({bool galleryTagRelationRefs})
    >;
typedef $$GalleryTableCreateCompanionBuilder = GalleryCompanion Function({
  Value<int> id,
  Value<String?> path,
  required String language,
  required String title,
  Value<String?> createDate,
  Value<String?> type,
  Value<int?> date,
  Value<int> mark,
  Value<int?> length,
});
typedef $$GalleryTableUpdateCompanionBuilder = GalleryCompanion Function({
  Value<int> id,
  Value<String?> path,
  Value<String> language,
  Value<String> title,
  Value<String?> createDate,
  Value<String?> type,
  Value<int?> date,
  Value<int> mark,
  Value<int?> length,
});

final class $$GalleryTableReferences
    extends BaseReferences<_$HitomiDatabase, $GalleryTable, GalleryRow> {
  $$GalleryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GalleryExtraTable, List<GalleryExtraRow>>
  _galleryExtraRefsTable(_$HitomiDatabase db) => MultiTypedResultKey.fromTable(
    db.galleryExtra,
    aliasName: 'Gallery__id__GalleryExtra__gid',
  );

  $$GalleryExtraTableProcessedTableManager get galleryExtraRefs {
    final manager = $$GalleryExtraTableTableManager(
      $_db,
      $_db.galleryExtra,
    ).filter((f) => f.gid.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_galleryExtraRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GalleryFileTable, List<GalleryFileRow>>
  _galleryFileRefsTable(_$HitomiDatabase db) => MultiTypedResultKey.fromTable(
    db.galleryFile,
    aliasName: 'Gallery__id__GalleryFile__gid',
  );

  $$GalleryFileTableProcessedTableManager get galleryFileRefs {
    final manager = $$GalleryFileTableTableManager(
      $_db,
      $_db.galleryFile,
    ).filter((f) => f.gid.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_galleryFileRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $GalleryTagRelationTable,
    List<GalleryTagRelationRow>
  >
  _galleryTagRelationRefsTable(_$HitomiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.galleryTagRelation,
        aliasName: 'Gallery__id__GalleryTagRelation__gid',
      );

  $$GalleryTagRelationTableProcessedTableManager get galleryTagRelationRefs {
    final manager = $$GalleryTagRelationTableTableManager(
      $_db,
      $_db.galleryTagRelation,
    ).filter((f) => f.gid.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _galleryTagRelationRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GalleryTableFilterComposer
    extends Composer<_$HitomiDatabase, $GalleryTable> {
  $$GalleryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mark => $composableBuilder(
    column: $table.mark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> galleryExtraRefs(
    Expression<bool> Function($$GalleryExtraTableFilterComposer f) f,
  ) {
    final $$GalleryExtraTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.galleryExtra,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryExtraTableFilterComposer(
            $db: $db,
            $table: $db.galleryExtra,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> galleryFileRefs(
    Expression<bool> Function($$GalleryFileTableFilterComposer f) f,
  ) {
    final $$GalleryFileTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.galleryFile,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryFileTableFilterComposer(
            $db: $db,
            $table: $db.galleryFile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> galleryTagRelationRefs(
    Expression<bool> Function($$GalleryTagRelationTableFilterComposer f) f,
  ) {
    final $$GalleryTagRelationTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.galleryTagRelation,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTagRelationTableFilterComposer(
            $db: $db,
            $table: $db.galleryTagRelation,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GalleryTableOrderingComposer
    extends Composer<_$HitomiDatabase, $GalleryTable> {
  $$GalleryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mark => $composableBuilder(
    column: $table.mark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GalleryTableAnnotationComposer
    extends Composer<_$HitomiDatabase, $GalleryTable> {
  $$GalleryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get createDate => $composableBuilder(
    column: $table.createDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get mark =>
      $composableBuilder(column: $table.mark, builder: (column) => column);

  GeneratedColumn<int> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  Expression<T> galleryExtraRefs<T extends Object>(
    Expression<T> Function($$GalleryExtraTableAnnotationComposer a) f,
  ) {
    final $$GalleryExtraTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.galleryExtra,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryExtraTableAnnotationComposer(
            $db: $db,
            $table: $db.galleryExtra,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> galleryFileRefs<T extends Object>(
    Expression<T> Function($$GalleryFileTableAnnotationComposer a) f,
  ) {
    final $$GalleryFileTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.galleryFile,
      getReferencedColumn: (t) => t.gid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryFileTableAnnotationComposer(
            $db: $db,
            $table: $db.galleryFile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> galleryTagRelationRefs<T extends Object>(
    Expression<T> Function($$GalleryTagRelationTableAnnotationComposer a) f,
  ) {
    final $$GalleryTagRelationTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.galleryTagRelation,
          getReferencedColumn: (t) => t.gid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GalleryTagRelationTableAnnotationComposer(
                $db: $db,
                $table: $db.galleryTagRelation,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$GalleryTableTableManager
    extends
        RootTableManager<
          _$HitomiDatabase,
          $GalleryTable,
          GalleryRow,
          $$GalleryTableFilterComposer,
          $$GalleryTableOrderingComposer,
          $$GalleryTableAnnotationComposer,
          $$GalleryTableCreateCompanionBuilder,
          $$GalleryTableUpdateCompanionBuilder,
          (GalleryRow, $$GalleryTableReferences),
          GalleryRow,
          PrefetchHooks Function({
            bool galleryExtraRefs,
            bool galleryFileRefs,
            bool galleryTagRelationRefs,
          })
        > {
  $$GalleryTableTableManager(_$HitomiDatabase db, $GalleryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GalleryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GalleryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GalleryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> createDate = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<int?> date = const Value.absent(),
                Value<int> mark = const Value.absent(),
                Value<int?> length = const Value.absent(),
              }) => GalleryCompanion(
                id: id,
                path: path,
                language: language,
                title: title,
                createDate: createDate,
                type: type,
                date: date,
                mark: mark,
                length: length,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> path = const Value.absent(),
                required String language,
                required String title,
                Value<String?> createDate = const Value.absent(),
                Value<String?> type = const Value.absent(),
                Value<int?> date = const Value.absent(),
                Value<int> mark = const Value.absent(),
                Value<int?> length = const Value.absent(),
              }) => GalleryCompanion.insert(
                id: id,
                path: path,
                language: language,
                title: title,
                createDate: createDate,
                type: type,
                date: date,
                mark: mark,
                length: length,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GalleryTable, GalleryRow>(table),
                  $$GalleryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                galleryExtraRefs = false,
                galleryFileRefs = false,
                galleryTagRelationRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (galleryExtraRefs) db.galleryExtra,
                    if (galleryFileRefs) db.galleryFile,
                    if (galleryTagRelationRefs) db.galleryTagRelation,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (galleryExtraRefs)
                        await $_getPrefetchedData<
                          GalleryRow,
                          $GalleryTable,
                          GalleryExtraRow
                        >(
                          currentTable: table,
                          referencedTable: $$GalleryTableReferences
                              ._galleryExtraRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GalleryTableReferences(
                                db,
                                table,
                                p0,
                              ).galleryExtraRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.gid == item.id),
                          typedResults: items,
                        ),
                      if (galleryFileRefs)
                        await $_getPrefetchedData<
                          GalleryRow,
                          $GalleryTable,
                          GalleryFileRow
                        >(
                          currentTable: table,
                          referencedTable: $$GalleryTableReferences
                              ._galleryFileRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GalleryTableReferences(
                                db,
                                table,
                                p0,
                              ).galleryFileRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.gid == item.id),
                          typedResults: items,
                        ),
                      if (galleryTagRelationRefs)
                        await $_getPrefetchedData<
                          GalleryRow,
                          $GalleryTable,
                          GalleryTagRelationRow
                        >(
                          currentTable: table,
                          referencedTable: $$GalleryTableReferences
                              ._galleryTagRelationRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GalleryTableReferences(
                                db,
                                table,
                                p0,
                              ).galleryTagRelationRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.gid == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GalleryTableProcessedTableManager =
    ProcessedTableManager<
      _$HitomiDatabase,
      $GalleryTable,
      GalleryRow,
      $$GalleryTableFilterComposer,
      $$GalleryTableOrderingComposer,
      $$GalleryTableAnnotationComposer,
      $$GalleryTableCreateCompanionBuilder,
      $$GalleryTableUpdateCompanionBuilder,
      (GalleryRow, $$GalleryTableReferences),
      GalleryRow,
      PrefetchHooks Function({
        bool galleryExtraRefs,
        bool galleryFileRefs,
        bool galleryTagRelationRefs,
      })
    >;
typedef $$GalleryExtraTableCreateCompanionBuilder =
    GalleryExtraCompanion Function({
      Value<int> id,
      required int gid,
      Value<Uint8List?> imageEmbedding,
      Value<String?> storyDescription,
      Value<Uint8List?> textEmbedding,
    });
typedef $$GalleryExtraTableUpdateCompanionBuilder =
    GalleryExtraCompanion Function({
      Value<int> id,
      Value<int> gid,
      Value<Uint8List?> imageEmbedding,
      Value<String?> storyDescription,
      Value<Uint8List?> textEmbedding,
    });

final class $$GalleryExtraTableReferences
    extends
        BaseReferences<_$HitomiDatabase, $GalleryExtraTable, GalleryExtraRow> {
  $$GalleryExtraTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GalleryTable _gidTable(_$HitomiDatabase db) =>
      db.gallery.createAlias('GalleryExtra__gid__Gallery__id');

  $$GalleryTableProcessedTableManager get gid {
    final $_column = $_itemColumn<int>('gid')!;

    final manager = $$GalleryTableTableManager(
      $_db,
      $_db.gallery,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GalleryExtraTableFilterComposer
    extends Composer<_$HitomiDatabase, $GalleryExtraTable> {
  $$GalleryExtraTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get imageEmbedding => $composableBuilder(
    column: $table.imageEmbedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storyDescription => $composableBuilder(
    column: $table.storyDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get textEmbedding => $composableBuilder(
    column: $table.textEmbedding,
    builder: (column) => ColumnFilters(column),
  );

  $$GalleryTableFilterComposer get gid {
    final $$GalleryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableFilterComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryExtraTableOrderingComposer
    extends Composer<_$HitomiDatabase, $GalleryExtraTable> {
  $$GalleryExtraTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get imageEmbedding => $composableBuilder(
    column: $table.imageEmbedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storyDescription => $composableBuilder(
    column: $table.storyDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get textEmbedding => $composableBuilder(
    column: $table.textEmbedding,
    builder: (column) => ColumnOrderings(column),
  );

  $$GalleryTableOrderingComposer get gid {
    final $$GalleryTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableOrderingComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryExtraTableAnnotationComposer
    extends Composer<_$HitomiDatabase, $GalleryExtraTable> {
  $$GalleryExtraTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get imageEmbedding => $composableBuilder(
    column: $table.imageEmbedding,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storyDescription => $composableBuilder(
    column: $table.storyDescription,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get textEmbedding => $composableBuilder(
    column: $table.textEmbedding,
    builder: (column) => column,
  );

  $$GalleryTableAnnotationComposer get gid {
    final $$GalleryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableAnnotationComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryExtraTableTableManager
    extends
        RootTableManager<
          _$HitomiDatabase,
          $GalleryExtraTable,
          GalleryExtraRow,
          $$GalleryExtraTableFilterComposer,
          $$GalleryExtraTableOrderingComposer,
          $$GalleryExtraTableAnnotationComposer,
          $$GalleryExtraTableCreateCompanionBuilder,
          $$GalleryExtraTableUpdateCompanionBuilder,
          (GalleryExtraRow, $$GalleryExtraTableReferences),
          GalleryExtraRow,
          PrefetchHooks Function({bool gid})
        > {
  $$GalleryExtraTableTableManager(_$HitomiDatabase db, $GalleryExtraTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GalleryExtraTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GalleryExtraTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GalleryExtraTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> gid = const Value.absent(),
                Value<Uint8List?> imageEmbedding = const Value.absent(),
                Value<String?> storyDescription = const Value.absent(),
                Value<Uint8List?> textEmbedding = const Value.absent(),
              }) => GalleryExtraCompanion(
                id: id,
                gid: gid,
                imageEmbedding: imageEmbedding,
                storyDescription: storyDescription,
                textEmbedding: textEmbedding,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int gid,
                Value<Uint8List?> imageEmbedding = const Value.absent(),
                Value<String?> storyDescription = const Value.absent(),
                Value<Uint8List?> textEmbedding = const Value.absent(),
              }) => GalleryExtraCompanion.insert(
                id: id,
                gid: gid,
                imageEmbedding: imageEmbedding,
                storyDescription: storyDescription,
                textEmbedding: textEmbedding,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GalleryExtraTable, GalleryExtraRow>(table),
                  $$GalleryExtraTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.gid,
                        referencedTable: $$GalleryExtraTableReferences
                            ._gidTable(db),
                        referencedColumn: $$GalleryExtraTableReferences
                            ._gidTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GalleryExtraTableProcessedTableManager =
    ProcessedTableManager<
      _$HitomiDatabase,
      $GalleryExtraTable,
      GalleryExtraRow,
      $$GalleryExtraTableFilterComposer,
      $$GalleryExtraTableOrderingComposer,
      $$GalleryExtraTableAnnotationComposer,
      $$GalleryExtraTableCreateCompanionBuilder,
      $$GalleryExtraTableUpdateCompanionBuilder,
      (GalleryExtraRow, $$GalleryExtraTableReferences),
      GalleryExtraRow,
      PrefetchHooks Function({bool gid})
    >;
typedef $$GalleryFileTableCreateCompanionBuilder =
    GalleryFileCompanion Function({
      Value<int?> gid,
      required String hash,
      required String name,
      Value<int?> width,
      Value<int?> height,
      Value<int?> fileHash,
      Value<int> rowid,
    });
typedef $$GalleryFileTableUpdateCompanionBuilder =
    GalleryFileCompanion Function({
      Value<int?> gid,
      Value<String> hash,
      Value<String> name,
      Value<int?> width,
      Value<int?> height,
      Value<int?> fileHash,
      Value<int> rowid,
    });

final class $$GalleryFileTableReferences
    extends
        BaseReferences<_$HitomiDatabase, $GalleryFileTable, GalleryFileRow> {
  $$GalleryFileTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GalleryTable _gidTable(_$HitomiDatabase db) =>
      db.gallery.createAlias('GalleryFile__gid__Gallery__id');

  $$GalleryTableProcessedTableManager? get gid {
    final $_column = $_itemColumn<int>('gid');
    if ($_column == null) return null;
    final manager = $$GalleryTableTableManager(
      $_db,
      $_db.gallery,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GalleryFileTableFilterComposer
    extends Composer<_$HitomiDatabase, $GalleryFileTable> {
  $$GalleryFileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  $$GalleryTableFilterComposer get gid {
    final $$GalleryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableFilterComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryFileTableOrderingComposer
    extends Composer<_$HitomiDatabase, $GalleryFileTable> {
  $$GalleryFileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  $$GalleryTableOrderingComposer get gid {
    final $$GalleryTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableOrderingComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryFileTableAnnotationComposer
    extends Composer<_$HitomiDatabase, $GalleryFileTable> {
  $$GalleryFileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  $$GalleryTableAnnotationComposer get gid {
    final $$GalleryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableAnnotationComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryFileTableTableManager
    extends
        RootTableManager<
          _$HitomiDatabase,
          $GalleryFileTable,
          GalleryFileRow,
          $$GalleryFileTableFilterComposer,
          $$GalleryFileTableOrderingComposer,
          $$GalleryFileTableAnnotationComposer,
          $$GalleryFileTableCreateCompanionBuilder,
          $$GalleryFileTableUpdateCompanionBuilder,
          (GalleryFileRow, $$GalleryFileTableReferences),
          GalleryFileRow,
          PrefetchHooks Function({bool gid})
        > {
  $$GalleryFileTableTableManager(_$HitomiDatabase db, $GalleryFileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GalleryFileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GalleryFileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GalleryFileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int?> gid = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> fileHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GalleryFileCompanion(
                gid: gid,
                hash: hash,
                name: name,
                width: width,
                height: height,
                fileHash: fileHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int?> gid = const Value.absent(),
                required String hash,
                required String name,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> fileHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GalleryFileCompanion.insert(
                gid: gid,
                hash: hash,
                name: name,
                width: width,
                height: height,
                fileHash: fileHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GalleryFileTable, GalleryFileRow>(table),
                  $$GalleryFileTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.gid,
                        referencedTable: $$GalleryFileTableReferences._gidTable(
                          db,
                        ),
                        referencedColumn: $$GalleryFileTableReferences
                            ._gidTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GalleryFileTableProcessedTableManager =
    ProcessedTableManager<
      _$HitomiDatabase,
      $GalleryFileTable,
      GalleryFileRow,
      $$GalleryFileTableFilterComposer,
      $$GalleryFileTableOrderingComposer,
      $$GalleryFileTableAnnotationComposer,
      $$GalleryFileTableCreateCompanionBuilder,
      $$GalleryFileTableUpdateCompanionBuilder,
      (GalleryFileRow, $$GalleryFileTableReferences),
      GalleryFileRow,
      PrefetchHooks Function({bool gid})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  required String title,
  required String path,
  Value<bool> completed,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> path,
  Value<bool> completed,
});

class $$TasksTableFilterComposer
    extends Composer<_$HitomiDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$HitomiDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$HitomiDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$HitomiDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, BaseReferences<_$HitomiDatabase, $TasksTable, TaskRow>),
          TaskRow,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$HitomiDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                path: path,
                completed: completed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String path,
                Value<bool> completed = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                path: path,
                completed: completed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRow>(table),
                  BaseReferences<_$HitomiDatabase, $TasksTable, TaskRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$HitomiDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, BaseReferences<_$HitomiDatabase, $TasksTable, TaskRow>),
      TaskRow,
      PrefetchHooks Function()
    >;
typedef $$UserLogTableCreateCompanionBuilder = UserLogCompanion Function({
  required int id,
  Value<int?> value,
  Value<int> type,
  Value<String?> content,
  Value<int?> date,
  Value<Uint8List?> extension,
  Value<int> rowid,
});
typedef $$UserLogTableUpdateCompanionBuilder = UserLogCompanion Function({
  Value<int> id,
  Value<int?> value,
  Value<int> type,
  Value<String?> content,
  Value<int?> date,
  Value<Uint8List?> extension,
  Value<int> rowid,
});

class $$UserLogTableFilterComposer
    extends Composer<_$HitomiDatabase, $UserLogTable> {
  $$UserLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get extension => $composableBuilder(
    column: $table.extension,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserLogTableOrderingComposer
    extends Composer<_$HitomiDatabase, $UserLogTable> {
  $$UserLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get extension => $composableBuilder(
    column: $table.extension,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserLogTableAnnotationComposer
    extends Composer<_$HitomiDatabase, $UserLogTable> {
  $$UserLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<Uint8List> get extension =>
      $composableBuilder(column: $table.extension, builder: (column) => column);
}

class $$UserLogTableTableManager
    extends
        RootTableManager<
          _$HitomiDatabase,
          $UserLogTable,
          UserLogRow,
          $$UserLogTableFilterComposer,
          $$UserLogTableOrderingComposer,
          $$UserLogTableAnnotationComposer,
          $$UserLogTableCreateCompanionBuilder,
          $$UserLogTableUpdateCompanionBuilder,
          (
            UserLogRow,
            BaseReferences<_$HitomiDatabase, $UserLogTable, UserLogRow>,
          ),
          UserLogRow,
          PrefetchHooks Function()
        > {
  $$UserLogTableTableManager(_$HitomiDatabase db, $UserLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> value = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<int?> date = const Value.absent(),
                Value<Uint8List?> extension = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserLogCompanion(
                id: id,
                value: value,
                type: type,
                content: content,
                date: date,
                extension: extension,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int id,
                Value<int?> value = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<int?> date = const Value.absent(),
                Value<Uint8List?> extension = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserLogCompanion.insert(
                id: id,
                value: value,
                type: type,
                content: content,
                date: date,
                extension: extension,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserLogTable, UserLogRow>(table),
                  BaseReferences<_$HitomiDatabase, $UserLogTable, UserLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserLogTableProcessedTableManager =
    ProcessedTableManager<
      _$HitomiDatabase,
      $UserLogTable,
      UserLogRow,
      $$UserLogTableFilterComposer,
      $$UserLogTableOrderingComposer,
      $$UserLogTableAnnotationComposer,
      $$UserLogTableCreateCompanionBuilder,
      $$UserLogTableUpdateCompanionBuilder,
      (UserLogRow, BaseReferences<_$HitomiDatabase, $UserLogTable, UserLogRow>),
      UserLogRow,
      PrefetchHooks Function()
    >;
typedef $$GalleryTagRelationTableCreateCompanionBuilder =
    GalleryTagRelationCompanion Function({
      Value<int?> gid,
      Value<int?> tid,
      Value<int?> type,
      Value<int> rowid,
    });
typedef $$GalleryTagRelationTableUpdateCompanionBuilder =
    GalleryTagRelationCompanion Function({
      Value<int?> gid,
      Value<int?> tid,
      Value<int?> type,
      Value<int> rowid,
    });

final class $$GalleryTagRelationTableReferences
    extends
        BaseReferences<
          _$HitomiDatabase,
          $GalleryTagRelationTable,
          GalleryTagRelationRow
        > {
  $$GalleryTagRelationTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GalleryTable _gidTable(_$HitomiDatabase db) =>
      db.gallery.createAlias('GalleryTagRelation__gid__Gallery__id');

  $$GalleryTableProcessedTableManager? get gid {
    final $_column = $_itemColumn<int>('gid');
    if ($_column == null) return null;
    final manager = $$GalleryTableTableManager(
      $_db,
      $_db.gallery,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tidTable(_$HitomiDatabase db) =>
      db.tags.createAlias('GalleryTagRelation__tid__Tags__id');

  $$TagsTableProcessedTableManager? get tid {
    final $_column = $_itemColumn<int>('tid');
    if ($_column == null) return null;
    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GalleryTagRelationTableFilterComposer
    extends Composer<_$HitomiDatabase, $GalleryTagRelationTable> {
  $$GalleryTagRelationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  $$GalleryTableFilterComposer get gid {
    final $$GalleryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableFilterComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tid {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tid,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryTagRelationTableOrderingComposer
    extends Composer<_$HitomiDatabase, $GalleryTagRelationTable> {
  $$GalleryTagRelationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  $$GalleryTableOrderingComposer get gid {
    final $$GalleryTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableOrderingComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tid {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tid,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryTagRelationTableAnnotationComposer
    extends Composer<_$HitomiDatabase, $GalleryTagRelationTable> {
  $$GalleryTagRelationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  $$GalleryTableAnnotationComposer get gid {
    final $$GalleryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gid,
      referencedTable: $db.gallery,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GalleryTableAnnotationComposer(
            $db: $db,
            $table: $db.gallery,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tid {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tid,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GalleryTagRelationTableTableManager
    extends
        RootTableManager<
          _$HitomiDatabase,
          $GalleryTagRelationTable,
          GalleryTagRelationRow,
          $$GalleryTagRelationTableFilterComposer,
          $$GalleryTagRelationTableOrderingComposer,
          $$GalleryTagRelationTableAnnotationComposer,
          $$GalleryTagRelationTableCreateCompanionBuilder,
          $$GalleryTagRelationTableUpdateCompanionBuilder,
          (GalleryTagRelationRow, $$GalleryTagRelationTableReferences),
          GalleryTagRelationRow,
          PrefetchHooks Function({bool gid, bool tid})
        > {
  $$GalleryTagRelationTableTableManager(
    _$HitomiDatabase db,
    $GalleryTagRelationTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GalleryTagRelationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GalleryTagRelationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GalleryTagRelationTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int?> gid = const Value.absent(),
                Value<int?> tid = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GalleryTagRelationCompanion(
                gid: gid,
                tid: tid,
                type: type,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int?> gid = const Value.absent(),
                Value<int?> tid = const Value.absent(),
                Value<int?> type = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GalleryTagRelationCompanion.insert(
                gid: gid,
                tid: tid,
                type: type,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GalleryTagRelationTable, GalleryTagRelationRow>(
                    table,
                  ),
                  $$GalleryTagRelationTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gid = false, tid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.gid,
                        referencedTable: $$GalleryTagRelationTableReferences
                            ._gidTable(db),
                        referencedColumn: $$GalleryTagRelationTableReferences
                            ._gidTable(db)
                            .id,
                      ) as T;
                    }
                    if (tid) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tid,
                        referencedTable: $$GalleryTagRelationTableReferences
                            ._tidTable(db),
                        referencedColumn: $$GalleryTagRelationTableReferences
                            ._tidTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GalleryTagRelationTableProcessedTableManager =
    ProcessedTableManager<
      _$HitomiDatabase,
      $GalleryTagRelationTable,
      GalleryTagRelationRow,
      $$GalleryTagRelationTableFilterComposer,
      $$GalleryTagRelationTableOrderingComposer,
      $$GalleryTagRelationTableAnnotationComposer,
      $$GalleryTagRelationTableCreateCompanionBuilder,
      $$GalleryTagRelationTableUpdateCompanionBuilder,
      (GalleryTagRelationRow, $$GalleryTagRelationTableReferences),
      GalleryTagRelationRow,
      PrefetchHooks Function({bool gid, bool tid})
    >;

class $HitomiDatabaseManager {
  final _$HitomiDatabase _db;
  $HitomiDatabaseManager(this._db);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$GalleryTableTableManager get gallery =>
      $$GalleryTableTableManager(_db, _db.gallery);
  $$GalleryExtraTableTableManager get galleryExtra =>
      $$GalleryExtraTableTableManager(_db, _db.galleryExtra);
  $$GalleryFileTableTableManager get galleryFile =>
      $$GalleryFileTableTableManager(_db, _db.galleryFile);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$UserLogTableTableManager get userLog =>
      $$UserLogTableTableManager(_db, _db.userLog);
  $$GalleryTagRelationTableTableManager get galleryTagRelation =>
      $$GalleryTagRelationTableTableManager(_db, _db.galleryTagRelation);
}
