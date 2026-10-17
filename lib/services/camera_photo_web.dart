import 'dart:typed_data';
import 'package:camera/camera.dart';

Future<Uint8List> readAndRemovePhoto(XFile photo) => photo.readAsBytes();
