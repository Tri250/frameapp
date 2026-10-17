import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/core/composition.dart';
import 'package:framecoach/core/level.dart';
import 'package:framecoach/core/vision.dart';

void main() {
  final start = DateTime(2026, 10, 11);
  const plan = CompositionPlan(
    CompositionKind.centered,
    .8,
    Point2(.5, .5),
    .5,
    'test',
  );
  SceneFeatures at(double x, double y) =>
      SceneFeatures(subject: Point2(x, y), subjectConfidence: .9);

  test('motion within the visible box earns and retains a full second', () {
    final tracker = AlignmentTracker();
    // The 14%-wide, 13%-high box still contains the target at every corner.
    const corners = [
      Point2(.44, .44),
      Point2(.56, .44),
      Point2(.56, .56),
      Point2(.44, .56),
    ];
    for (int i = 0; i <= 12; i++) {
      final p = corners[i % corners.length];
      final result = tracker.update(
        plan,
        at(p.x, p.y),
        start.add(Duration(milliseconds: i * 120)),
      );
      expect(result.valid, true);
      expect(result.progress, closeTo((i * .12).clamp(0, 1), .001));
      expect(result.ready, i >= 9);
    }
  });

  test('leaving either edge requires a new full second inside the box', () {
    for (final outside in [
      const Point2(.429, .5),
      const Point2(.571, .5),
      const Point2(.5, .434),
      const Point2(.5, .566),
    ]) {
      final tracker = AlignmentTracker();
      for (int i = 0; i <= 5; i++) {
        tracker.update(
          plan,
          at(.5, .5),
          start.add(Duration(milliseconds: i * 200)),
        );
      }
      final left = tracker.update(
        plan,
        at(outside.x, outside.y),
        start.add(const Duration(milliseconds: 1100)),
      );
      expect(left.ready, false);
      expect(left.progress, 0);
      for (int i = 0; i <= 5; i++) {
        final result = tracker.update(
          plan,
          at(.5, .5),
          start.add(Duration(milliseconds: 1200 + i * 200)),
        );
        expect(result.ready, i == 5, reason: 'outside=$outside, frame=$i');
        expect(result.progress, closeTo(i * .2, .001));
      }
    }
  });

  test('direction hints correct the axis that is outside the box', () {
    final tracker = AlignmentTracker();
    expect(tracker.update(plan, at(.42, .44), start).message, contains('稍向左'));
    expect(tracker.update(plan, at(.58, .56), start).message, contains('稍向右'));
    expect(tracker.update(plan, at(.435, .43), start).message, contains('稍向上'));
    expect(tracker.update(plan, at(.565, .57), start).message, contains('稍向下'));
  });

  test(
    'loss, stale samples and strong shaking still reset an aligned hold',
    () {
      for (final reason in ['loss', 'stale', 'shake']) {
        final tracker = AlignmentTracker();
        for (int i = 0; i <= 5; i++) {
          tracker.update(
            plan,
            at(.5, .5),
            start.add(Duration(milliseconds: i * 200)),
          );
        }
        final time = start.add(
          Duration(milliseconds: reason == 'stale' ? 2000 : 1200),
        );
        final result = tracker.update(
          plan,
          reason == 'loss' ? const SceneFeatures() : at(.5, .5),
          time,
          level: LevelReading(moving: reason == 'shake'),
        );
        expect(result.ready, false, reason: reason);
        expect(result.progress, 0, reason: reason);
      }
    },
  );
}
