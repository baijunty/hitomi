class Gallery {
  List<Groups>? groups;
  String? title;
  List<int>? related;
  String? language;
  List<Languages>? languages;
  dynamic videofilename;
  List<Artists>? artists;
  dynamic video;
  String? galleryurl;
  String? date;
  late List<Files> files;
  List<dynamic>? sceneIndexes;
  List<Tags>? tags;
  String? id;
  String? japaneseTitle;
  List<Parodys>? parodys;
  String? languageUrl;
  List<Characters>? characters;
  String? languageLocalname;
  String? type;

  Gallery(
      {this.groups,
      this.title,
      this.related,
      this.language,
      this.languages,
      this.videofilename,
      this.artists,
      this.video,
      this.galleryurl,
      this.date,
      required this.files,
      this.sceneIndexes,
      this.tags,
      this.id,
      this.japaneseTitle,
      this.parodys,
      this.languageUrl,
      this.characters,
      this.languageLocalname,
      this.type});

  Gallery.fromJson(Map<String, dynamic> json) {
    groups = json["groups"] == null
        ? null
        : (json["groups"] as List).map((e) => Groups.fromJson(e)).toList();
    title = json["title"];
    related = json["related"] == null ? null : List<int>.from(json["related"]);
    language = json["language"];
    languages = json["languages"] == null
        ? null
        : (json["languages"] as List)
            .map((e) => Languages.fromJson(e))
            .toList();
    videofilename = json["videofilename"];
    artists = json["artists"] == null
        ? null
        : (json["artists"] as List).map((e) => Artists.fromJson(e)).toList();
    video = json["video"];
    galleryurl = json["galleryurl"];
    date = json["date"];
    files = (json["files"] as List).map((e) => Files.fromJson(e)).toList();
    sceneIndexes = json["scene_indexes"] ?? [];
    tags = json["tags"] == null
        ? null
        : (json["tags"] as List).map((e) => Tags.fromJson(e)).toList();
    id = json["id"];
    japaneseTitle = json["japanese_title"];
    parodys = json["parodys"] == null
        ? null
        : (json["parodys"] as List).map((e) => Parodys.fromJson(e)).toList();
    languageUrl = json["language_url"];
    characters = json["characters"] == null
        ? null
        : (json["characters"] as List)
            .map((e) => Characters.fromJson(e))
            .toList();
    languageLocalname = json["language_localname"];
    type = json["type"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    if (groups != null) {
      _data["groups"] = groups?.map((e) => e.toJson()).toList();
    }
    _data["title"] = title;
    if (related != null) {
      _data["related"] = related;
    }
    _data["language"] = language;
    if (languages != null) {
      _data["languages"] = languages?.map((e) => e.toJson()).toList();
    }
    _data["videofilename"] = videofilename;
    if (artists != null) {
      _data["artists"] = artists?.map((e) => e.toJson()).toList();
    }
    _data["video"] = video;
    _data["galleryurl"] = galleryurl;
    _data["date"] = date;
    _data["files"] = files.map((e) => e.toJson()).toList();
    if (sceneIndexes != null) {
      _data["scene_indexes"] = sceneIndexes;
    }
    if (tags != null) {
      _data["tags"] = tags?.map((e) => e.toJson()).toList();
    }
    _data["id"] = id;
    _data["japanese_title"] = japaneseTitle;
    if (parodys != null) {
      _data["parodys"] = parodys?.map((e) => e.toJson()).toList();
    }
    _data["language_url"] = languageUrl;
    if (characters != null) {
      _data["characters"] = characters?.map((e) => e.toJson()).toList();
    }
    _data["language_localname"] = languageLocalname;
    _data["type"] = type;
    return _data;
  }

  @override
  String toString() {
    return '{title:$title,id:$id,size:${files.length},aritist:$artists,language:$languageLocalname,seials:$parodys }';
  }
}

class Characters {
  String? character;
  String? url;

  Characters({this.character, this.url});

  Characters.fromJson(Map<String, dynamic> json) {
    character = json["character"];
    url = json["url"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["character"] = character;
    _data["url"] = url;
    return _data;
  }
}

class Parodys {
  String? url;
  String? parody;

  Parodys({this.url, this.parody});

  Parodys.fromJson(Map<String, dynamic> json) {
    url = json["url"];
    parody = json["parody"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["url"] = url;
    _data["parody"] = parody;
    return _data;
  }
}

class Tags {
  String? url;
  String? male;
  String? female;
  String? tag;

  Tags({this.url, this.male, this.female, this.tag});

  Tags.fromJson(Map<String, dynamic> json) {
    url = json["url"];
    male = json["male"]?.toString();
    female = json["female"]?.toString();
    tag = json["tag"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["url"] = url;
    _data["male"] = male;
    _data["female"] = female;
    _data["tag"] = tag;
    return _data;
  }
}

class Files {
  late int width;
  late int height;
  late String hash;
  late int hasavif;
  late int haswebp;
  late String name;

  Files(
      {required this.width,
      required this.height,
      required this.hash,
      required this.hasavif,
      required this.haswebp,
      required this.name});

  Files.fromJson(Map<String, dynamic> json) {
    width = json["width"];
    height = json["height"];
    hash = json["hash"];
    hasavif = json["hasavif"];
    haswebp = json["haswebp"];
    name = json["name"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["width"] = width;
    _data["height"] = height;
    _data["hash"] = hash;
    _data["hasavif"] = hasavif;
    _data["haswebp"] = haswebp;
    _data["name"] = name;
    return _data;
  }
}

class Artists {
  String? artist;
  String? url;

  Artists({this.artist, this.url});

  Artists.fromJson(Map<String, dynamic> json) {
    artist = json["artist"];
    url = json["url"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["artist"] = artist;
    _data["url"] = url;
    return _data;
  }
}

class Languages {
  late String galleryid;
  late String languageLocalname;
  late String name;
  late String url;

  Languages(this.galleryid, this.languageLocalname, this.name, this.url);

  Languages.fromJson(Map<String, dynamic> json) {
    galleryid = json["galleryid"]!;
    languageLocalname = json["language_localname"]!;
    name = json["name"]!;
    url = json["url"]!;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["galleryid"] = galleryid;
    _data["language_localname"] = languageLocalname;
    _data["name"] = name;
    _data["url"] = url;
    return _data;
  }
}

class Groups {
  String? group;
  String? url;

  Groups({this.group, this.url});

  Groups.fromJson(Map<String, dynamic> json) {
    group = json["group"];
    url = json["url"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["group"] = group;
    _data["url"] = url;
    return _data;
  }
}
