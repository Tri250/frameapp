import 'dart:math' as math;
import 'dart:typed_data';
import 'vision.dart';

/// Immutable camera input that can be sent to the analysis isolate. Sampling
/// the source footprint must happen before reducing fine texture to 192x256.
class CameraPlane {
  const CameraPlane({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rowStride,
    required this.pixelStride,
    required this.bgra,
    required this.rotation,
    required this.mirror,
  });
  final Uint8List bytes;
  final int width, height, rowStride, pixelStride, rotation;
  final bool bgra, mirror;

  GrayFrame sample() => sampleCameraPlane(
    bytes: bytes,
    width: width,
    height: height,
    rowStride: rowStride,
    pixelStride: pixelStride,
    bgra: bgra,
    rotation: rotation,
    mirror: mirror,
    outputWidth: 192,
    outputHeight: 256,
  );
}

/// Area-filter the centered 3:4 crop, respecting native strides, then orient the
/// small image. A single source-pixel lookup aliases foliage into moving noise;
/// smoothing after that lookup cannot recover the discarded scene information.
GrayFrame sampleCameraPlane({
  required Uint8List bytes,
  required int width,
  required int height,
  required int rowStride,
  int pixelStride = 1,
  bool bgra = false,
  int rotation = 0,
  bool mirror = false,
  int outputWidth = 96,
  int outputHeight = 128,
}) {
  final outW = outputWidth, outH = outputHeight;
  final rotated = rotation == 90 || rotation == 270;
  final uprightW = rotated ? height : width,
      uprightH = rotated ? width : height;
  final cropW = math.min(uprightW.toDouble(), uprightH * .75);
  final cropH = cropW / .75;
  final channels = bgra ? 3 : 1;
  if (width <= 0 ||
      height <= 0 ||
      outW <= 0 ||
      outH <= 0 ||
      pixelStride < channels ||
      rowStride < (width - 1) * pixelStride + channels ||
      bytes.length <
          (height - 1) * rowStride + (width - 1) * pixelStride + channels) {
    throw StateError('相机图像缓冲区不完整');
  }
  final nativeW = rotated ? outH : outW, nativeH = rotated ? outW : outH;
  final nativeCropW = rotated ? cropH : cropW;
  final nativeCropH = rotated ? cropW : cropH;
  final columns = _sampleAreas(
    width,
    (width - nativeCropW) / 2,
    nativeCropW,
    nativeW,
  );
  final rows = _sampleAreas(
    height,
    (height - nativeCropH) / 2,
    nativeCropH,
    nativeH,
  );
  final native = Uint8List(nativeW * nativeH);
  for (int y = 0; y < nativeH; y++) {
    for (int x = 0; x < nativeW; x++) {
      double value = 0;
      for (final (sy, wy) in rows[y]) {
        final row = sy * rowStride;
        for (final (sx, wx) in columns[x]) {
          final i = row + sx * pixelStride;
          final luminance = bgra
              ? (bytes[i + 2] * 77 + bytes[i + 1] * 150 + bytes[i] * 29) >> 8
              : bytes[i];
          value += luminance * wx * wy;
        }
      }
      native[y * nativeW + x] = value.round().clamp(0, 255);
    }
  }
  final pixels = Uint8List(outW * outH);
  for (int y = 0; y < outH; y++) {
    for (int x = 0; x < outW; x++) {
      final u = mirror ? outW - 1 - x : x, v = y;
      final (sx, sy) = switch (rotation) {
        90 => (v, nativeH - 1 - u),
        180 => (nativeW - 1 - u, nativeH - 1 - v),
        270 => (nativeW - 1 - v, u),
        _ => (u, v),
      };
      pixels[y * outW + x] = native[sy * nativeW + sx];
    }
  }
  return GrayFrame(outW, outH, pixels);
}

List<List<(int, double)>> _sampleAreas(
  int limit,
  double start,
  double extent,
  int count,
) {
  final step = extent / count;
  return List.generate(count, (index) {
    final left = start + index * step, right = start + (index + 1) * step;
    if (step <= 1) {
      return [(((left + right) / 2).floor().clamp(0, limit - 1), 1.0)];
    }
    return [
      for (
        int pixel = math.max(0, left.floor());
        pixel < math.min(limit, right.ceil());
        pixel++
      )
        (pixel, (math.min(right, pixel + 1) - math.max(left, pixel)) / step),
    ];
  });
}
