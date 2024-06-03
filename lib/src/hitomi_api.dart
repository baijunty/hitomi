import 'dart:io';

import 'package:dio/dio.dart';

import '../gallery/gallery.dart';
import '../gallery/image.dart';
import '../gallery/label.dart';
import 'response.dart';

abstract class Hitomi {
  void registerCallBack(Future<bool> callBack(Message msg));
  void removeCallBack(Future<bool> callBack(Message msg));
  Future<bool> downloadImages(Gallery gallery,
      {bool usePrefence = true, CancelToken? token});
  Future<Gallery> fetchGallery(dynamic id,
      {bool usePrefence = true, CancelToken? token});
  Future<DataResponse<List<int>>> search(List<Label> include,
      {List<Label> exclude,
      int page = 1,
      CancelToken? token,
      SortEnum sort = SortEnum.Default});
  Future<List<Map<String, dynamic>>> fetchSuggestions(String key);
  Future<DataResponse<List<Gallery>>> findSimilarGalleryBySearch(
      Gallery gallery,
      {CancelToken? token});
  Future<List<Map<String, dynamic>>> translate(List<Label> labels,
      {CancelToken? token});
  Future<List<int>> fetchImageData(Image image,
      {String refererUrl,
      CancelToken? token,
      int id = 0,
      ThumbnaiSize size = ThumbnaiSize.smaill,
      void Function(int now, int total)? onProcess});
  Future<DataResponse<List<Gallery>>> viewByTag(Label tag,
      {int page = 1, CancelToken? token, SortEnum? sort});
}

enum SortEnum { Default, Date, DateDesc, week, month, year }

sealed class Message<T> {
  final T id;
  Message({required this.id});

  @override
  String toString() {
    return 'Message {$id}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    if (other is! Message) return false;
    return other.id == id;
  }
}

class TaskStartMessage<T> extends Message<int> {
  Gallery gallery;
  FileSystemEntity file;
  T target;
  TaskStartMessage(this.gallery, this.file, this.target)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'TaskStartMessage{$id,${file.path},${target}, ${gallery.files.length} }';
  }
}

class DownLoadingMessage extends Message<int> {
  Gallery gallery;
  int current;
  double speed;
  int length;
  DownLoadingMessage(this.gallery, this.current, this.speed, this.length)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'DownLoadMessage{$id,$current $speed,$length }';
  }

  Map<String, dynamic> get toMap => {
        'gallery': this.gallery,
        'current': this.current,
        'speed': this.speed,
        'length': this.length
      };
}

class DownLoadFinished<T> extends Message<int> {
  Gallery gallery;
  FileSystemEntity file;
  T target;
  bool success;
  DownLoadFinished(this.target, this.gallery, this.file, this.success)
      : super(id: gallery.id);
  @override
  String toString() {
    return 'DownLoadFinished{$id,${file.path},${target} $success }';
  }
}

class IlleagalGallery extends Message<int> {
  String errorMsg;
  int index;
  IlleagalGallery(dynamic id, this.errorMsg, this.index) : super(id: id);
}
