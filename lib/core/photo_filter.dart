import 'dart:math' as math;
import 'dart:ui' as ui;

enum PhotoStyle { original, warm, clear, film, monochrome }

enum PhotoAdjustment { brightness, contrast, saturation, warmth }

/// One immutable recipe for both the viewfinder and the exported photograph.
class PhotoFilter {
  const PhotoFilter({
    this.style = PhotoStyle.original,
    this.intensity = 1,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
  }) : assert(intensity >= 0 && intensity <= 1),
       assert(brightness >= -1 && brightness <= 1),
       assert(contrast >= -1 && contrast <= 1),
       assert(saturation >= -1 && saturation <= 1),
       assert(warmth >= -1 && warmth <= 1);

  final PhotoStyle style;
  final double intensity;

  /// Signed adjustments in [-1, 1], independent of the preset's strength.
  final double brightness, contrast, saturation, warmth;
  bool get hasAdjustments =>
      brightness != 0 || contrast != 0 || saturation != 0 || warmth != 0;
  bool get isOriginal =>
      (style == PhotoStyle.original || intensity == 0) && !hasAdjustments;

  double adjustment(PhotoAdjustment adjustment) => switch (adjustment) {
    PhotoAdjustment.brightness => brightness,
    PhotoAdjustment.contrast => contrast,
    PhotoAdjustment.saturation => saturation,
    PhotoAdjustment.warmth => warmth,
  };

  PhotoFilter copyWith({
    PhotoStyle? style,
    double? intensity,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) => PhotoFilter(
    style: style ?? this.style,
    intensity: intensity ?? this.intensity,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
  );

  List<double> get matrix {
    final (
      presetSaturation,
      presetContrast,
      red,
      green,
      blue,
      lift,
    ) = switch (style) {
      PhotoStyle.original => (1.0, 1.0, 1.0, 1.0, 1.0, 0.0),
      PhotoStyle.warm => (.94, 1.035, 1.055, 1.005, .95, 1.0),
      PhotoStyle.clear => (1.08, 1.05, .985, 1.012, 1.035, 0.0),
      PhotoStyle.film => (.76, .90, 1.04, 1.015, .965, 4.0),
      PhotoStyle.monochrome => (0.0, 1.08, 1.0, 1.0, 1.0, 0.0),
    };
    const luminance = [.2126, .7152, .0722];
    final balance = [red, green, blue];
    final result = List<double>.filled(20, 0);
    for (var channel = 0; channel < 3; channel++) {
      for (var source = 0; source < 3; source++) {
        final identity = channel == source ? 1.0 : 0.0;
        final value =
            (luminance[source] * (1 - presetSaturation) +
                identity * presetSaturation) *
            presetContrast *
            balance[channel];
        result[channel * 5 + source] =
            identity + (value - identity) * intensity;
      }
      result[channel * 5 + 4] =
          ((1 - presetContrast) * 127.5 + lift) * intensity;
    }
    result[18] = 1;
    // Preserve the original preset coefficients exactly at neutral settings.
    if (!hasAdjustments) return result;

    // Preset → saturation (0–2×) → contrast (0.5–1.5× about mid-gray)
    // → brightness (±51 levels) and warmth (±20 red/opposite blue levels).
    // Compose into one affine transform; clamp only when rendering the pixel.
    // Strength zero removes the preset, but keeps these explicit adjustments.
    final saturationScale = 1 + saturation;
    final contrastScale = 1 + contrast * .5;
    final adjusted = List<double>.filled(20, 0);
    for (var channel = 0; channel < 3; channel++) {
      for (var intermediate = 0; intermediate < 3; intermediate++) {
        final weight =
            (luminance[intermediate] * (1 - saturationScale) +
                (channel == intermediate ? saturationScale : 0)) *
            contrastScale;
        for (var source = 0; source < 5; source++) {
          adjusted[channel * 5 + source] +=
              weight * result[intermediate * 5 + source];
        }
      }
      adjusted[channel * 5 + 4] +=
          (1 - contrastScale) * 127.5 +
          brightness * 51 +
          (channel == 0
              ? warmth * 20
              : channel == 2
              ? -warmth * 20
              : 0);
    }
    adjusted[18] = 1;
    return adjusted;
  }

  ui.ColorFilter? get colorFilter =>
      isOriginal ? null : ui.ColorFilter.matrix(matrix);

  double get vignette => switch (style) {
    PhotoStyle.film => .24 * intensity,
    PhotoStyle.monochrome => .14 * intensity,
    _ => 0,
  };

  double get grain => style == PhotoStyle.film ? .10 * intensity : 0;

  @override
  bool operator ==(Object other) =>
      other is PhotoFilter &&
      style == other.style &&
      intensity == other.intensity &&
      brightness == other.brightness &&
      contrast == other.contrast &&
      saturation == other.saturation &&
      warmth == other.warmth;

  @override
  int get hashCode =>
      Object.hash(style, intensity, brightness, contrast, saturation, warmth);
}

final _grainPoints = () {
  final random = math.Random(417);
  return List.generate(
    1800,
    (_) => (random.nextDouble(), random.nextDouble(), random.nextBool()),
    growable: false,
  );
}();

/// Positions and texture sizes use the cropped image's coordinates, so changing
/// output resolution does not change the recipe. No UI overlays are painted here.
void paintPhotoTexture(ui.Canvas canvas, ui.Size size, PhotoFilter filter) {
  if (filter.isOriginal) return;
  final bounds = ui.Offset.zero & size;
  canvas.save();
  canvas.clipRect(bounds);
  if (filter.vignette > 0) {
    canvas.drawRect(
      bounds,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          bounds.center,
          size.longestSide * .66,
          [
            const ui.Color(0x00000000),
            const ui.Color(0x00000000),
            const ui.Color(0xFF000000).withValues(alpha: filter.vignette),
          ],
          [0, .36, 1],
        ),
    );
  }
  if (filter.grain > 0) {
    final light = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: filter.grain);
    final dark = ui.Paint()
      ..color = const ui.Color(0xFF000000).withValues(alpha: filter.grain);
    for (final point in _grainPoints) {
      canvas.drawCircle(
        ui.Offset(point.$1 * size.width, point.$2 * size.height),
        size.shortestSide / 750,
        point.$3 ? light : dark,
      );
    }
  }
  canvas.restore();
}

Future<ui.Image> renderPhoto(
  ui.Image image,
  ui.Rect source, {
  PhotoFilter filter = const PhotoFilter(),
  bool mirror = false,
}) async {
  final width = source.width.round(), height = source.height.round();
  final size = ui.Size(width.toDouble(), height.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.save();
  if (mirror) {
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
  }
  canvas.drawImageRect(
    image,
    source,
    ui.Offset.zero & size,
    ui.Paint()..colorFilter = filter.colorFilter,
  );
  canvas.restore();
  paintPhotoTexture(canvas, size, filter);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}
