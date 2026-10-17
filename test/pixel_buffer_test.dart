import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/core/pixel_buffer.dart';
import 'package:framecoach/core/vision.dart';

// Fine, fixed scene texture below the tracking resolution, like dense foliage.
// Moving the camera changes the sampled pixels, not the scene's identity.
GrayFrame fineTextureCameraFrame(int pan) {
  const width = 768, height = 1024;
  final pixels = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final u = x + pan, v = y - pan;
      var hash = (u * 374761393 + v * 668265263) & 0x7fffffff;
      hash = ((hash ^ (hash >> 13)) * 1274126177) & 0x7fffffff;
      pixels[y * width + x] =
          (120 +
                  22 * math.sin(u / 19) * math.cos(v / 27) +
                  16 * math.sin((u + v) / 33) +
                  (hash % 121 - 60))
              .round()
              .clamp(0, 255);
    }
  }
  return GrayFrame(width, height, pixels);
}

GrayFrame _samplePlane(CameraPlane plane) => plane.sample();

Future<GrayFrame> sampleTrackingFrame(GrayFrame source) => compute(
  _samplePlane,
  CameraPlane(
    bytes: source.pixels,
    width: source.width,
    height: source.height,
    rowStride: source.width,
    pixelStride: 1,
    bgra: false,
    rotation: 0,
    mirror: false,
  ),
);

void main() {
  test('downsampling keeps the mean of fine detail instead of one pixel', () {
    final bytes = Uint8List(12 * 16);
    for (int y = 2; y < 16; y += 4) {
      for (int x = 2; x < 12; x += 4) {
        bytes[y * 12 + x] = 255;
      }
    }
    final frame = sampleCameraPlane(
      bytes: bytes,
      width: 12,
      height: 16,
      rowStride: 12,
      outputWidth: 3,
      outputHeight: 4,
    );
    expect(frame.pixels, everyElement(16));
  });

  test('fractional source areas contribute proportionally when shrinking', () {
    final bytes = Uint8List.fromList([
      for (int y = 0; y < 16; y++)
        for (int x = 0; x < 10; x++) x * 10,
    ]);
    final frame = sampleCameraPlane(
      bytes: bytes,
      width: 10,
      height: 16,
      rowStride: 10,
      outputWidth: 3,
      outputHeight: 4,
    );
    expect(frame.pixels, [
      for (int y = 0; y < 4; y++) ...[12, 45, 78],
    ]);
  });

  test(
    'filtered camera pixels keep rotation, mirroring and native strides',
    () {
      for (final rotation in [0, 90, 180, 270]) {
        for (final bgra in [false, true]) {
          final rotated = rotation == 90 || rotation == 270;
          final width = rotated ? 16 : 12, height = rotated ? 12 : 16;
          final stride = bgra ? 4 : 2, rowStride = width * stride + 7;
          final bytes = Uint8List(rowStride * height)
            ..fillRange(0, rowStride * height, 255);
          for (int v = 0; v < 16; v++) {
            for (int u = 0; u < 12; u++) {
              final (x, y) = switch (rotation) {
                90 => (v, height - 1 - u),
                180 => (width - 1 - u, height - 1 - v),
                270 => (width - 1 - v, u),
                _ => (u, v),
              };
              final value = 10 + 30 * (u ~/ 4) + 5 * (v ~/ 4);
              final i = y * rowStride + x * stride;
              bytes[i] = value;
              if (bgra) {
                bytes[i + 1] = value;
                bytes[i + 2] = value;
              }
            }
          }
          for (final mirror in [false, true]) {
            final frame = sampleCameraPlane(
              bytes: bytes,
              width: width,
              height: height,
              rowStride: rowStride,
              pixelStride: stride,
              bgra: bgra,
              rotation: rotation,
              mirror: mirror,
              outputWidth: 3,
              outputHeight: 4,
            );
            expect(frame.pixels, [
              for (int y = 0; y < 4; y++)
                for (int x = 0; x < 3; x++)
                  10 + 30 * (mirror ? 2 - x : x) + 5 * y,
            ], reason: 'rotation=$rotation, BGRA=$bgra, mirror=$mirror');
          }
        }
      }
    },
  );

  test(
    'native one-pixel camera jitter does not lose a fine-textured subject',
    () async {
      final lock = SubjectLock()
        ..select(
          await sampleTrackingFrame(fineTextureCameraFrame(0)),
          const Point2(.5, .5),
        );
      final reference = lock.tracking!.reference;
      for (final pan in [1, 2, 3, 2, 1, 0, -1, -2, -3, -2, -1, 0]) {
        final frame = await sampleTrackingFrame(fineTextureCameraFrame(pan));
        lock.acceptTracking(lock.tracking!.advance(frame));
        expect(lock.state, SubjectState.tracking, reason: 'native pan=$pan');
        expect(lock.position!.x, closeTo(.5 - pan / 768, .004));
        expect(lock.position!.y, closeTo(.5 + pan / 1024, .004));
        expect(lock.tracking!.reference, same(reference));
      }
      final last = lock.position;
      lock.acceptTracking(
        lock.tracking!.advance(
          GrayFrame(
            192,
            256,
            Uint8List(192 * 256)..fillRange(0, 192 * 256, 110),
          ),
        ),
      );
      expect(lock.state, SubjectState.lost);
      expect(lock.position, same(last));
      lock.acceptTracking(
        lock.tracking!.advance(
          await sampleTrackingFrame(fineTextureCameraFrame(2)),
        ),
      );
      expect(lock.state, SubjectState.tracking);
      expect(lock.tracking!.reference, same(reference));
      expect(lock.position!.x, closeTo(.5 - 2 / 768, .004));
      expect(lock.position!.y, closeTo(.5 + 2 / 1024, .004));
    },
  );
}
