import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/core/vision.dart';
import 'package:framecoach/core/pixel_buffer.dart';
import 'package:framecoach/core/composition.dart';
import 'package:framecoach/core/level.dart';

GrayFrame subjectFrame(int cx, int cy, {bool show = true}) {
  final pixels = Uint8List(96 * 128)..fillRange(0, 96 * 128, 110);
  if (show) {
    for (int y = cy - 9; y < cy + 9; y++) {
      for (int x = cx - 6; x < cx + 6; x++) {
        if (x >= 0 && x < 96 && y >= 0 && y < 128) {
          pixels[y * 96 + x] =
              ((x - cx + 6) * 31 + (y - cy + 9) * 19) % 180 + 30;
        }
      }
    }
  }
  return GrayFrame(96, 128, pixels);
}

void main() {
  test(
    'screenshot cases allow aligned capture despite roll or weak symmetry',
    () {
      final start = DateTime(2026);
      final cases = [
        (
          CompositionKind.centered,
          const LevelReading(angle: -6.5),
          const Point2(.510, .498),
        ),
        (
          CompositionKind.symmetry,
          const LevelReading(elevation: -45),
          const Point2(.526, .5),
        ),
      ];
      for (final (kind, level, subject) in cases) {
        final tracker = AlignmentTracker();
        final plan = CompositionPlan(
          kind,
          .5,
          const Point2(.5, .5),
          .5,
          'test',
        );
        final features = SceneFeatures(
          subject: subject,
          subjectConfidence: 1,
          symmetry: .2,
        );
        for (int i = 0; i <= 5; i++) {
          final result = tracker.update(
            plan,
            features,
            start.add(Duration(milliseconds: 240 * i)),
            level: level,
          );
          expect(
            result.ready,
            i == 5,
            reason: '${kind.name}: ${result.message}',
          );
        }
      }
    },
  );
  test('flat image has neither subject nor confident horizon/symmetry', () {
    final result = const FrameAnalyzer().analyze(
      subjectFrame(48, 64, show: false),
    );
    expect(result.subject, isNull);
    expect(result.horizonConfidence, lessThan(.2));
    expect(result.symmetry, 0);
  });
  test('appearance tracker follows pixels, and loses an absent subject', () {
    const point = Point2(.5, .5);
    final template = SubjectTemplate.capture(subjectFrame(48, 64), point)!;
    final shifted = template.match(subjectFrame(56, 70), point);
    expect(shifted.point, isNotNull);
    expect(shifted.point!.x, closeTo(56 / 96, .015));
    expect(shifted.point!.y, closeTo(70 / 128, .015));
    expect(
      template.match(subjectFrame(56, 70, show: false), point).point,
      isNull,
    );
  });
  test('edge selection keeps tracking with the same sampling as capture', () {
    const point = Point2(3 / 96, 64 / 128);
    final template = SubjectTemplate.capture(subjectFrame(3, 64), point)!;
    final match = template.match(subjectFrame(5, 65), point);
    expect(match.point, isNotNull);
    expect(match.point!.x, closeTo(5 / 96, .015));
    expect(match.point!.y, closeTo(65 / 128, .015));
  });
  test('lost tracking retains last confirmed marker and reacquires pixels', () {
    final lock = SubjectLock()
      ..select(subjectFrame(48, 64), const Point2(.5, .5));
    final shifted = analyzeRequest(
      AnalysisRequest(
        subjectFrame(54, 69),
        lock.template,
        lock.position,
        subjectLocked: true,
      ),
    );
    lock.accept(shifted);
    final last = lock.position;
    lock.accept(
      analyzeRequest(
        AnalysisRequest(
          subjectFrame(54, 69, show: false),
          lock.template,
          last,
          subjectLocked: true,
        ),
      ),
    );
    expect(lock.state, SubjectState.lost);
    expect(lock.position, same(last));
    lock.accept(
      analyzeRequest(
        AnalysisRequest(
          subjectFrame(56, 70),
          lock.template,
          last,
          subjectLocked: true,
        ),
      ),
    );
    expect(lock.state, SubjectState.tracking);
    expect(lock.position!.x, closeTo(56 / 96, .015));
  });
  test(
    'low detail selection stays visible and auto saliency cannot replace it',
    () {
      final lock = SubjectLock()
        ..select(subjectFrame(48, 64, show: false), const Point2(.2, .3));
      expect(lock.template, isNull);
      expect(lock.state, SubjectState.needsDetail);
      final result = analyzeRequest(
        AnalysisRequest(
          subjectFrame(70, 90),
          lock.template,
          lock.position,
          subjectLocked: lock.selected,
        ),
      );
      expect(
        const FrameAnalyzer().analyze(subjectFrame(70, 90)).subject,
        isNotNull,
      );
      expect(result.subject, isNull);
      lock.accept(result);
      expect(lock.position!.x, .2);
      expect(lock.position!.y, .3);
      expect(lock.state, SubjectState.needsDetail);
    },
  );
  test('pixel reader respects padded rows, sensor rotation and mirroring', () {
    final bytes = Uint8List.fromList([
      10,
      20,
      30,
      40,
      255,
      255,
      50,
      60,
      70,
      80,
      255,
      255,
      90,
      100,
      110,
      120,
      255,
      255,
      130,
      140,
      150,
      160,
      255,
      255,
    ]);
    final rotated = sampleCameraPlane(
      bytes: bytes,
      width: 4,
      height: 4,
      rowStride: 6,
      rotation: 90,
    );
    expect(rotated.pixels.first, 130);
    expect(rotated.pixels[95], 10);
    final mirrored = sampleCameraPlane(
      bytes: bytes,
      width: 4,
      height: 4,
      rowStride: 6,
      rotation: 90,
      mirror: true,
    );
    expect(mirrored.pixels.first, 10);
    expect(mirrored.pixels[95], 130);
  });
  test('BGRA sampler uses luminance rather than a color byte', () {
    final bytes = Uint8List.fromList([255, 0, 0, 255]);
    final result = sampleCameraPlane(
      bytes: bytes,
      width: 1,
      height: 1,
      rowStride: 4,
      pixelStride: 4,
      bgra: true,
    );
    expect(result.pixels.first, 28);
  });
  test('recommendations respond to a symmetric scene', () {
    final plans = const CompositionRecommender().recommend(
      const SceneFeatures(symmetry: .99),
    );
    expect(plans.first.kind, CompositionKind.symmetry);
    expect(plans.map((p) => p.kind).toSet().length, 6);
  });
  test(
    'an explicit lost selection cannot silently become horizon alignment',
    () {
      final plans = const CompositionRecommender().recommend(
        const SceneFeatures(horizonConfidence: 1),
        selectedSubject: const Point2(.2, .3),
      );
      expect(plans.every((p) => !p.useHorizon), true);
      expect(
        plans.firstWhere((p) => p.kind == CompositionKind.thirds).target.x,
        1 / 3,
      );
    },
  );
  group('live readiness', () {
    const plan = CompositionPlan(
      CompositionKind.thirds,
      .8,
      Point2(2 / 3, 2 / 3),
      1 / 3,
      'test',
    );
    const aligned = SceneFeatures(
      subject: Point2(2 / 3, 2 / 3),
      subjectConfidence: .9,
    );
    final start = DateTime(2026);
    test(
      'requires a full stable second; movement immediately revokes readiness',
      () {
        final tracker = AlignmentTracker();
        expect(tracker.update(plan, aligned, start).ready, false);
        for (int i = 1; i <= 4; i++) {
          expect(
            tracker
                .update(
                  plan,
                  aligned,
                  start.add(Duration(milliseconds: i * 240)),
                )
                .ready,
            false,
          );
        }
        expect(
          tracker
              .update(
                plan,
                aligned,
                start.add(const Duration(milliseconds: 1200)),
              )
              .ready,
          true,
        );
        expect(
          tracker
              .update(
                plan,
                const SceneFeatures(
                  subject: Point2(.2, .2),
                  subjectConfidence: .9,
                ),
                start.add(const Duration(milliseconds: 1400)),
              )
              .ready,
          false,
        );
      },
    );
    test('lost subject and long gaps never count as stable', () {
      final tracker = AlignmentTracker();
      tracker.update(plan, aligned, start);
      expect(
        tracker
            .update(plan, aligned, start.add(const Duration(seconds: 2)))
            .ready,
        false,
      );
      expect(
        tracker
            .update(
              plan,
              const SceneFeatures(),
              start.add(const Duration(milliseconds: 2200)),
            )
            .valid,
        false,
      );
    });
    test('constant tilt is advice while sensor motion prevents readiness', () {
      final tracker = AlignmentTracker();
      final result = tracker.update(
        plan,
        const SceneFeatures(
          subject: Point2(2 / 3, 2 / 3),
          subjectConfidence: 1,
          horizonConfidence: .9,
          horizonAngle: 6,
        ),
        start,
        level: const LevelReading(angle: 6),
      );
      expect(result.advice, contains('更水平'));
      expect(result.progress, 0);
      tracker.reset();
      const sloping = SceneFeatures(
        subject: Point2(2 / 3, 2 / 3),
        subjectConfidence: 1,
        horizonConfidence: .9,
        horizonAngle: 20,
      );
      for (int i = 0; i <= 5; i++) {
        final result = tracker.update(
          plan,
          sloping,
          start.add(Duration(milliseconds: i * 240)),
          level: const LevelReading(angle: -6.5),
        );
        expect(result.ready, i == 5);
        expect(result.advice, contains('更水平'));
      }
      expect(
        tracker
            .update(
              plan,
              sloping,
              start.add(const Duration(milliseconds: 1440)),
              level: const LevelReading(moving: true),
            )
            .ready,
        false,
      );
    });
  });
  test(
    'small jitter permits readiness while weak symmetry remains optional advice',
    () {
      final tracker = AlignmentTracker();
      const plan = CompositionPlan(
        CompositionKind.centered,
        .8,
        Point2(.5, .5),
        .5,
        'test',
      );
      final start = DateTime(2026);
      for (int i = 0; i < 10; i++) {
        final result = tracker.update(
          plan,
          SceneFeatures(
            subject: Point2(i.isEven ? .48 : .52, .5),
            subjectConfidence: 1,
          ),
          start.add(Duration(milliseconds: i * 240)),
        );
        expect(result.ready, i >= 5);
      }
      tracker.reset();
      const symmetric = CompositionPlan(
        CompositionKind.symmetry,
        .8,
        Point2(.5, .5),
        .5,
        'test',
      );
      for (int i = 0; i <= 5; i++) {
        final result = tracker.update(
          symmetric,
          const SceneFeatures(
            subject: Point2(.5, .5),
            subjectConfidence: 1,
            symmetry: .2,
          ),
          start.add(Duration(milliseconds: i * 240)),
        );
        expect(result.advice, contains('更对称'));
        expect(result.ready, i == 5);
      }
    },
  );
}
