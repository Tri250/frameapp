import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';

Future<Uint8List> readAndRemovePhoto(XFile photo) async {
  try {
    return await photo.readAsBytes();
  } finally {
    try {
      await File(photo.path).delete();
    } on FileSystemException {
      // Camera caches can already be removed by the platform.
    }
  }
}
