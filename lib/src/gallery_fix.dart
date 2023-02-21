import 'dart:io';
import 'prefenerce.dart';

class GalleryFix {
  final UserContext context;
  GalleryFix(this.context);
  Future<void> fix() async {
    Directory d = Directory(context.outPut);
    d.list().takeWhile((event) => event is Directory);
  }
}
