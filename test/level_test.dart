import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/core/level.dart';
import 'package:framecoach/core/composition.dart';
import 'package:framecoach/core/vision.dart';

void main() {
  final start = DateTime(2026);
  test(
    'gravity roll is smoothed and has the expected correction direction',
    () {
      final filter = LevelFilter();
      expect(filter.add(0, 9.81, 0, start).angle, 0);
      final x = -9.81 * math.sin(10 * math.pi / 180);
      final y = 9.81 * math.cos(10 * math.pi / 180);
      final first = filter.add(
        x,
        y,
        0,
        start.add(const Duration(milliseconds: 50)),
      );
      expect(first.angle, lessThan(5));
      LevelReading reading = first;
      for (int i = 2; i <= 20; i++) {
        reading = filter.add(
          x,
          y,
          0,
          start.add(Duration(milliseconds: i * 50)),
        );
      }
      expect(reading.angle, closeTo(10, .5));
      expect(reading.label, contains('右倾'));
      expect(reading.needsLeveling, true);
      expect(reading.blocksAlignment, false);
    },
  );
  test(
    'flat phone has undefined roll; movement and sensor absence are distinct',
    () {
      final filter = LevelFilter();
      final flat = filter.add(0, 0, 9.81, start);
      expect(flat.angle, isNull);
      expect(flat.label, '俯拍');
      expect(
        filter
            .add(0, 15, 0, start.add(const Duration(milliseconds: 50)))
            .moving,
        true,
      );
      expect(const LevelReading(available: false).blocksAlignment, false);
      filter.reset();
      expect(
        filter.add(0, 9.81, 0, start.add(const Duration(seconds: 2))).angle,
        0,
      );
    },
  );
  test('upward and downward camera poses do not require portrait roll', () {
    for (final elevation in [
      35.0,
      50.0,
      70.0,
      90.0,
      110.0,
      125.0,
      -35.0,
      -80.0,
    ]) {
      final filter = LevelFilter();
      final pitch = elevation * math.pi / 180;
      const roll = 6 * math.pi / 180;
      final reading = filter.add(
        -9.81 * math.cos(pitch) * math.sin(roll),
        9.81 * math.cos(pitch) * math.cos(roll),
        -9.81 * math.sin(pitch),
        start,
      );
      expect(reading.angle, isNull, reason: 'elevation=$elevation');
      expect(reading.blocksAlignment, false, reason: 'elevation=$elevation');
      expect(reading.label, elevation > 0 ? '仰拍' : '俯拍');
    }
  });
  test(
    'pose labels follow the active camera without changing capture readiness',
    () {
      final rear = LevelFilter().add(0, 4.905, -8.496, start);
      final front = LevelFilter().add(
        0,
        4.905,
        -8.496,
        start,
        frontCamera: true,
      );
      expect(rear.label, '仰拍');
      expect(front.label, '俯拍');
      expect(rear.blocksAlignment, false);
      expect(front.blocksAlignment, false);
    },
  );
  test(
    'raising the camera changes the pose label and returning upright restores roll advice',
    () {
      final filter = LevelFilter();
      LevelReading sample(double elevation, DateTime now) {
        final pitch = elevation * math.pi / 180;
        const roll = 8 * math.pi / 180;
        return filter.add(
          -9.81 * math.cos(pitch) * math.sin(roll),
          9.81 * math.cos(pitch) * math.cos(roll),
          -9.81 * math.sin(pitch),
          now,
        );
      }

      expect(sample(0, start).needsLeveling, true);
      expect(sample(0, start).blocksAlignment, false);
      expect(
        sample(65, start.add(const Duration(milliseconds: 50))).blocksAlignment,
        false,
      );
      // Small elevation changes while holding the shot must not flicker back to
      // a blocked shutter, then an upright pose must regain its roll guidance.
      for (int i = 0; i < 20; i++) {
        final reading = sample(
          i.isEven ? 29 : 31,
          start.add(Duration(milliseconds: 100 + i * 50)),
        );
        expect(reading.blocksAlignment, false);
      }
      LevelReading returned = const LevelReading();
      for (int i = 0; i < 20; i++) {
        returned = sample(0, start.add(Duration(milliseconds: 1100 + i * 50)));
      }
      expect(returned.angle, closeTo(8, .5));
      expect(returned.needsLeveling, true);
      expect(returned.blocksAlignment, false);
      filter.reset();
      expect(
        filter.add(0, 9.81, 0, start.add(const Duration(seconds: 3))).angle,
        0,
      );
    },
  );
  test(
    'crossing the top does not mistake inverted gravity for a 180 degree roll',
    () {
      final reading = LevelFilter().add(0, -9.81, 0, start);
      expect(reading.angle, 0);
      expect(reading.blocksAlignment, false);
      final tilted = LevelFilter().add(-1.7, -9.66, 0, start);
      expect(tilted.angle!.abs(), closeTo(10, .5));
      expect(tilted.needsLeveling, true);
      expect(tilted.blocksAlignment, false);
    },
  );
  test('aligned subjects can become ready in an upward camera pose', () {
    for (final elevation in [65.0, 120.0, -65.0]) {
      final filter = LevelFilter();
      final tracker = AlignmentTracker();
      const plan = CompositionPlan(
        CompositionKind.centered,
        .8,
        Point2(.5, .5),
        .5,
        'test',
      );
      const features = SceneFeatures(
        subject: Point2(.5, .5),
        subjectConfidence: 1,
      );
      final pitch = elevation * math.pi / 180;
      for (int i = 0; i <= 5; i++) {
        final now = start.add(Duration(milliseconds: i * 240));
        final level = filter.add(
          -.4,
          9.81 * math.cos(pitch),
          -9.81 * math.sin(pitch),
          now,
        );
        final result = tracker.update(plan, features, now, level: level);
        expect(result.ready, i == 5, reason: 'elevation=$elevation, frame=$i');
      }
      final shaking = filter.add(
        0,
        15 * math.cos(pitch),
        -15 * math.sin(pitch),
        start.add(const Duration(milliseconds: 1440)),
      );
      expect(
        tracker
            .update(
              plan,
              features,
              start.add(const Duration(milliseconds: 1440)),
              level: shaking,
            )
            .ready,
        false,
      );
      expect(
        tracker
            .update(
              plan,
              const SceneFeatures(),
              start.add(const Duration(milliseconds: 1680)),
              level: filter.add(
                0,
                9.81 * math.cos(pitch),
                -9.81 * math.sin(pitch),
                start.add(const Duration(milliseconds: 1680)),
              ),
            )
            .ready,
        false,
      );
    }
  });
}
