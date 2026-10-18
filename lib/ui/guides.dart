import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/composition.dart';
import '../core/vision.dart';

const ink = Color(0xFF101311),
    paper = Color(0xFFF2F0E7),
    acid = Color(0xFFD7F574),
    muted = Color(0xFF90978E);

class GuidePainter extends CustomPainter {
  GuidePainter({
    this.plan,
    required this.features,
    this.subjectPosition,
    this.subjectTracked = false,
    this.ready = false,
    this.showGuides = false,
  });
  final CompositionPlan? plan;
  final SceneFeatures features;
  final Point2? subjectPosition;
  final bool subjectTracked;
  final bool ready, showGuides;
  @override
  void paint(Canvas c, Size s) {
    final line = Paint()
      ..color = paper.withValues(alpha: .65)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final accent = Paint()
      ..color = ready ? acid : paper
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    Offset at(Point2 p) => Offset(p.x * s.width, p.y * s.height);
    void dash(Offset a, Offset b, [Paint? pen]) {
      final length = (b - a).distance;
      if (length == 0) {
        return;
      }
      final direction = (b - a) / length;
      for (double i = 0; i < length; i += 11) {
        c.drawLine(
          a + direction * i,
          a + direction * math.min(i + 5, length),
          pen ?? line,
        );
      }
    }

    if (showGuides && plan != null) {
      final target = at(plan!.target);
      switch (plan!.kind) {
        case CompositionKind.thirds:
          for (final f in [1 / 3, 2 / 3]) {
            dash(Offset(s.width * f, 0), Offset(s.width * f, s.height));
            dash(Offset(0, s.height * f), Offset(s.width, s.height * f));
          }
        case CompositionKind.centered:
          dash(Offset(s.width / 2, 0), Offset(s.width / 2, s.height));
          dash(Offset(0, s.height / 2), Offset(s.width, s.height / 2));
        case CompositionKind.symmetry:
          dash(Offset(s.width / 2, 0), Offset(s.width / 2, s.height));
          for (final f in [.25, .75]) {
            c.drawLine(
              Offset(s.width * f, s.height * .47),
              Offset(s.width * f, s.height * .53),
              line,
            );
          }
        case CompositionKind.golden:
          for (final f in [.382, .618]) {
            dash(Offset(s.width * f, 0), Offset(s.width * f, s.height));
          }
          final spiral = Path();
          final flipX = plan!.target.x < .5 ? 1 : -1,
              flipY = plan!.target.y < .5 ? 1 : -1;
          for (int i = 0; i <= 220; i++) {
            final theta = i / 220 * math.pi * 5;
            final radius =
                s.width *
                .85 *
                math.exp(-math.log(1.618) / (math.pi / 2) * theta);
            final p =
                target +
                Offset(
                  math.cos(theta) * radius * flipX,
                  math.sin(theta) * radius * flipY,
                );
            if (i == 0) {
              spiral.moveTo(p.dx, p.dy);
            } else {
              spiral.lineTo(p.dx, p.dy);
            }
          }
          c.drawPath(spiral, line);
        case CompositionKind.leading:
          for (final p in [
            Offset(0, s.height),
            Offset(s.width, s.height),
            Offset(0, s.height * .55),
            Offset(s.width, s.height * .55),
          ]) {
            dash(p, target);
          }
        case CompositionKind.negativeSpace:
          dash(Offset(0, target.dy), Offset(s.width, target.dy));
          final empty = Rect.fromLTWH(
            plan!.target.x < .5 ? s.width * .48 : s.width * .07,
            s.height * .12,
            s.width * .45,
            s.height * .42,
          );
          final corners = Paint()
            ..color = paper.withValues(alpha: .3)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke;
          c.drawRRect(
            RRect.fromRectAndRadius(empty, const Radius.circular(12)),
            corners,
          );
      }
      if (!plan!.useHorizon) {
        c.drawCircle(
          target,
          19,
          Paint()..color = acid.withValues(alpha: ready ? .22 : .10),
        );
        c.drawCircle(
          target,
          14,
          Paint()
            ..color = acid
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        c.drawLine(
          target + const Offset(-5, 0),
          target + const Offset(5, 0),
          accent..color = acid,
        );
        c.drawLine(
          target + const Offset(0, -5),
          target + const Offset(0, 5),
          accent,
        );
      }
    }
    if (subjectTracked && subjectPosition != null) {
      // The frame style reports live tracking confidence: solid and bright
      // while strong, dashed and faint while the lock is only recovering.
      final confidence = features.subjectConfidence.clamp(0.0, 1.0);
      final p = at(subjectPosition!),
          r = Rect.fromCenter(
            center: p,
            width: s.width * subjectGuideWidth,
            height: s.height * subjectGuideHeight,
          );
      final pen = Paint()
        ..color = (ready ? acid : paper).withValues(
          alpha: .55 + .45 * confidence,
        )
        ..strokeWidth = confidence >= .6 ? 2 : 1.5
        ..style = PaintingStyle.stroke;
      const l = 9.0;
      for (final corner in [
        (r.topLeft, 1.0, 1.0),
        (r.topRight, -1.0, 1.0),
        (r.bottomLeft, 1.0, -1.0),
        (r.bottomRight, -1.0, -1.0),
      ]) {
        final horizontal = (corner.$1, corner.$1 + Offset(l * corner.$2, 0));
        final vertical = (corner.$1, corner.$1 + Offset(0, l * corner.$3));
        if (confidence >= .6) {
          c.drawLine(horizontal.$1, horizontal.$2, pen);
          c.drawLine(vertical.$1, vertical.$2, pen);
        } else {
          dash(horizontal.$1, horizontal.$2, pen);
          dash(vertical.$1, vertical.$2, pen);
        }
      }
      c.drawCircle(p, 2.5, Paint()..color = pen.color);
    }
    // A direction cue shows how far the white box still has to travel toward
    // the target; moving the phone the opposite way moves the box along it.
    if (showGuides &&
        plan != null &&
        !plan!.useHorizon &&
        subjectTracked &&
        subjectPosition != null) {
      final delta = at(plan!.target) - at(subjectPosition!);
      final distance = delta.distance;
      final dx = plan!.target.x - subjectPosition!.x,
          dy = plan!.target.y - subjectPosition!.y;
      if (distance > 1 &&
          (dx.abs() > subjectGuideWidth / 2 ||
              dy.abs() > subjectGuideHeight / 2)) {
        final unit = delta / distance;
        final half = Offset(
          s.width * subjectGuideWidth / 2,
          s.height * subjectGuideHeight / 2,
        );
        final edge = math.min(
          unit.dx.abs() < 1e-6 ? double.infinity : half.dx / unit.dx.abs(),
          unit.dy.abs() < 1e-6 ? double.infinity : half.dy / unit.dy.abs(),
        );
        final start = at(subjectPosition!) + unit * (edge + 3);
        final end = at(plan!.target) - unit * 24;
        if ((end - start).distance > 12) {
          final arrow = Paint()
            ..color = acid.withValues(alpha: .9)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke;
          dash(start, end, arrow);
          final back = end - unit * 9, wing = Offset(-unit.dy, unit.dx) * 5.5;
          c.drawLine(end, back + wing, arrow);
          c.drawLine(end, back - wing, arrow);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GuidePainter old) => true;
}

class DemoPhotoPainter extends CustomPainter {
  const DemoPhotoPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant DemoPhotoPainter old) =>
      old.source != source || old.image != image;
}

/// The one-second stable hold as a ring around the shutter button.
class ShutterRingPainter extends CustomPainter {
  ShutterRingPainter({required this.progress, required this.ready});
  final double progress;
  final bool ready;
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    final radius = math.min(s.width, s.height) / 2 - 3;
    c.drawCircle(
      center,
      radius,
      Paint()
        ..color = paper.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final value = progress.clamp(0.0, 1.0);
    if (value > 0) {
      c.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..color = ready ? acid : paper.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ShutterRingPainter old) =>
      old.progress != progress || old.ready != ready;
}

/// A compact roll gauge beside the level label: the marker slides away from
/// center as tilt grows. Purely advisory; roll never gates the shutter.
class LevelGaugePainter extends CustomPainter {
  LevelGaugePainter({required this.angle, required this.level});
  final double? angle;
  final bool level;
  @override
  void paint(Canvas c, Size s) {
    final cy = s.height / 2;
    final track = Paint()
      ..color = paper.withValues(alpha: .28)
      ..strokeWidth = 1;
    c.drawLine(Offset(0, cy), Offset(s.width, cy), track);
    final center = Offset(s.width / 2, cy);
    c.drawLine(center - Offset(0, 3), center + Offset(0, 3), track);
    final value = (angle ?? 0).clamp(-15.0, 15.0) / 15;
    final marker = center + Offset(value * (s.width / 2 - 4), 0);
    c.drawCircle(
      marker,
      3,
      Paint()
        ..color = angle == null
            ? paper.withValues(alpha: .35)
            : level
            ? acid
            : const Color(0xFFF4B66F),
    );
  }

  @override
  bool shouldRepaint(covariant LevelGaugePainter old) =>
      old.angle != angle || old.level != level;
}
