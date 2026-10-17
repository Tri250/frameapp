import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'gallery_error.dart';

Future<void> savePhoto(Uint8List bytes, String filename) async {
  const permissionHint = '请在系统设置中允许相册访问，再点「重新保存」。';
  try {
    if (!await Gal.hasAccess()) {
      throw const PhotoSaveException(permissionHint);
    }
    await Gal.putImageBytes(bytes, name: filename);
  } on GalException catch (error) {
    throw PhotoSaveException(switch (error.type) {
      GalExceptionType.accessDenied => permissionHint,
      GalExceptionType.notEnoughSpace => '手机空间不足，请清理空间后点「重新保存」。',
      _ => '保存未完成，请点「重新保存」再试一次。',
    });
  }
}
