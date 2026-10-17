import 'dart:math' as math;

class LevelReading {
  const LevelReading({
    this.angle,
    this.moving = false,
    this.available = true,
    this.waiting = false,
    this.elevation,
  });
  final double? angle, elevation;
  final bool moving, available, waiting;
  // Roll is a photographic preference, not a reason to disable the shutter.
  bool get needsLeveling => angle != null && angle!.abs() > 2.5;
  bool get blocksAlignment => moving;
  String get label {
    if (!available) return '不可用';
    if (waiting) return '准备中';
    if (moving) return '请稳住手机';
    if (elevation != null) return elevation! > 0 ? '仰拍' : '俯拍';
    if (angle == null) return '请竖起手机';
    if (angle!.abs() <= 2.5) return '水平 ${angle!.abs().toStringAsFixed(1)}°';
    return '${angle! > 0 ? '右倾' : '左倾'} ${angle!.abs().toStringAsFixed(1)}°';
  }
}

/// Use all three gravity axes to distinguish camera elevation from sideways
/// roll. For steep shots, screen-plane roll is advisory and must not gate capture.
class LevelFilter {
  double? _x, _y, _z;
  bool _elevated = false;
  DateTime? _last;
  LevelReading add(
    double x,
    double y,
    double z,
    DateTime now, {
    bool frontCamera = false,
  }) {
    final dt = _last == null
        ? .05
        : now.difference(_last!).inMicroseconds / 1e6;
    final alpha = _last == null || dt > 1 ? 1.0 : 1 - math.exp(-dt / .18);
    _x = (_x ?? x) + alpha * (x - (_x ?? x));
    _y = (_y ?? y) + alpha * (y - (_y ?? y));
    _z = (_z ?? z) + alpha * (z - (_z ?? z));
    _last = now;
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < 7.8 || magnitude > 11.8) {
      return const LevelReading(moving: true);
    }
    final smoothMagnitude = math.sqrt(_x! * _x! + _y! * _y! + _z! * _z!);
    // Camera direction reverses the pose label, while screen roll stays the same.
    final cameraDirection = frontCamera ? 1.0 : -1.0;
    final rawElevation = math.asin(
      (cameraDirection * z / magnitude).clamp(-1.0, 1.0),
    );
    final smoothElevation = smoothMagnitude < 1
        ? rawElevation
        : math.asin((cameraDirection * _z! / smoothMagnitude).clamp(-1.0, 1.0));
    // Enter using the current sample as well as filtered gravity so an old roll
    // cannot keep rejecting a newly elevated shot. Hysteresis avoids flickering
    // at the boundary; returning upright also waits for the vector to settle.
    final elevated = math.max(rawElevation.abs(), smoothElevation.abs());
    _elevated = elevated >= (_elevated ? 25 : 30) * math.pi / 180;
    if (_elevated) {
      final elevation = rawElevation.abs() >= smoothElevation.abs()
          ? rawElevation
          : smoothElevation;
      return LevelReading(elevation: elevation * 180 / math.pi);
    }
    if (math.sqrt(x * x + y * y) < 3 || math.sqrt(_x! * _x! + _y! * _y!) < 3) {
      return const LevelReading();
    }
    final raw = math.atan2(-_x!, _y!) * 180 / math.pi;
    // Opposite vertical directions describe the same level line. Crossing over
    // the top must not turn a straight frame into a 180-degree leveling error.
    final roll = (raw + 90) % 180 - 90;
    return LevelReading(angle: (roll * 2).round() / 2);
  }

  void reset() {
    _x = _y = _z = null;
    _elevated = false;
    _last = null;
  }
}
