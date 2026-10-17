import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/core/vision.dart';
import 'package:framecoach/core/scene_evidence.dart';
import 'package:framecoach/core/composition.dart';

GrayFrame fixture(String name) {
  final bytes = Uint8List(96 * 128)..fillRange(0, 96 * 128, 115);
  for (int y = 0; y < 128; y++) {
    for (int x = 0; x < 96; x++) {
      switch (name) {
        case 'center':
        case 'space':
          final cx = name == 'center' ? 48 : 65;
          final cy = name == 'center' ? 64 : 82;
          final rx = name == 'center' ? 18 : 5;
          final ry = name == 'center' ? 26 : 8;
          if (math.pow((x - cx) / rx, 2) + math.pow((y - cy) / ry, 2) < 1) {
            bytes[y * 96 + x] =
                200 + ((x - cx).abs() * 7 + (y - cy).abs() * 3) % 40;
          }
        case 'symmetry':
          final xx = math.min(x, 95 - x);
          if ((xx > 12 && xx < 19) ||
              (xx > 30 && xx < 37) ||
              (y % 32 < 5 && xx > 10)) {
            bytes[y * 96 + x] = 225;
          }
        case 'road':
          final left = 48 - (y - 38) * .46;
          final right = 48 + (y - 38) * .46;
          if (y > 38 && ((x - left).abs() < 1.7 || (x - right).abs() < 1.7)) {
            bytes[y * 96 + x] = 235;
          }
        case 'golden':
          // An off-center focal object with busy, unequal contextual weight.
          final value = 85 + ((x * 17 + y * 13 + x * y) % (x < 48 ? 120 : 70));
          bytes[y * 96 + x] = value;
          if (math.pow((x - 59) / 5, 2) + math.pow((y - 79) / 8, 2) < 1) {
            bytes[y * 96 + x] = 225 + (x * 7 + y * 3) % 25;
          }
        case 'horizon':
          bytes[y * 96 + x] = y < 52 ? 200 : 55;
        case 'blank':
          break;
      }
    }
  }
  return GrayFrame(96, 128, bytes);
}

List<CompositionPlan> plansFor(GrayFrame frame, {Point2? selected}) {
  final template = selected == null
      ? null
      : SubjectTemplate.capture(frame, selected);
  final analysis = analyzeComposition(
    AnalysisRequest(frame, template, selected, subjectLocked: selected != null),
  );
  return const CompositionRecommender().recommend(
    analysis.features,
    selectedSubject: selected,
    evidence: analysis.evidence,
  );
}

void main() {
  test(
    'different actual pixels favor different methods, without a thirds prior',
    () {
      final scenarios = {
        'center': (const Point2(.5, .5), CompositionKind.centered),
        'space': (
          const Point2(65 / 96, 82 / 128),
          CompositionKind.negativeSpace,
        ),
        'symmetry': (null, CompositionKind.symmetry),
        'road': (null, CompositionKind.leading),
        'horizon': (null, CompositionKind.thirds),
        'golden': (const Point2(59 / 96, 79 / 128), CompositionKind.golden),
      };
      for (final entry in scenarios.entries) {
        final frame = fixture(entry.key), selected = entry.value.$1;
        final features = const FrameAnalyzer().analyze(frame);
        final evidence = SceneEvidence.measure(
          frame,
          features.withSubject(
            selected ?? features.subject,
            selected == null ? features.subjectConfidence : 1,
          ),
          selectedSubject: selected,
        );
        final plans = plansFor(frame, selected: selected);
        // A useful failure includes measurements rather than just rank numbers.
        expect(
          plans.first.kind,
          entry.value.$2,
          reason:
              '${entry.key}: ${plans.map((p) => '${p.kind.name}=${p.score.toStringAsFixed(2)}').join(', ')}; area=${evidence.subjectArea}; isolation=${evidence.isolation}; symmetry=${evidence.symmetry}; lines=${evidence.leading}; quiet=${evidence.leftSpace},${evidence.rightSpace}',
        );
      }
    },
  );
  test('blank pixels produce no confident recommendation', () {
    final plans = plansFor(fixture('blank'));
    expect(plans.every((p) => p.score == 0), true);
    expect(plans.first.kind, CompositionKind.centered);
    expect(plans.every((p) => p.evidenceLabel == '依据较少'), true);
  });
  test('negative space gives advice without blocking aligned capture', () {
    const plan = CompositionPlan(
      CompositionKind.negativeSpace,
      .8,
      Point2(2 / 3, 2 / 3),
      1 / 3,
      'test',
    );
    const features = SceneFeatures(
      subject: Point2(2 / 3, 2 / 3),
      subjectConfidence: 1,
      subjectArea: .04,
    );
    final tracker = AlignmentTracker();
    final start = DateTime(2026);
    for (int i = 0; i < 6; i++) {
      final result = tracker.update(
        plan,
        features,
        start.add(Duration(milliseconds: 240 * i)),
        evidence: const SceneEvidence(
          subjectArea: .04,
          leftSpace: .2,
          rightSpace: .3,
        ),
      );
      expect(result.ready, i == 5);
      expect(result.advice, contains('更多空白'));
    }
    tracker.reset();
    for (int i = 0; i < 6; i++) {
      final result = tracker.update(
        plan,
        features,
        start.add(Duration(milliseconds: 240 * i)),
        evidence: const SceneEvidence(subjectArea: .04, leftSpace: .9),
      );
      expect(result.ready, i == 5);
      expect(result.advice, isNull);
    }
  });
  test(
    'subject area measures the selected region, not a different salient object',
    () {
      final small = analyzeComposition(
        AnalysisRequest(
          fixture('space'),
          SubjectTemplate.capture(
            fixture('space'),
            const Point2(65 / 96, 82 / 128),
          ),
          const Point2(65 / 96, 82 / 128),
          subjectLocked: true,
        ),
      );
      final large = analyzeComposition(
        AnalysisRequest(
          fixture('center'),
          SubjectTemplate.capture(fixture('center'), const Point2(.5, .5)),
          const Point2(.5, .5),
          subjectLocked: true,
        ),
      );
      expect(small.evidence.subjectArea, isNotNull);
      expect(
        large.evidence.subjectArea,
        greaterThan(small.evidence.subjectArea! * 4),
      );
    },
  );
  test(
    'horizontal bands cannot masquerade as facade symmetry or converging arms',
    () {
      final frame = fixture('horizon');
      final e = SceneEvidence.measure(
        frame,
        const FrameAnalyzer().analyze(frame),
      );
      expect(e.symmetry, lessThan(.2));
      expect(e.leading, lessThan(.2));
    },
  );
  test(
    'golden ratio needs opposing visual weight; position alone is insufficient',
    () {
      final weaker = const CompositionRecommender().recommend(
        const SceneFeatures(subject: Point2(.618, .618), subjectConfidence: 1),
        evidence: const SceneEvidence(
          detail: 1,
          subject: Point2(.618, .618),
          subjectConfidence: 1,
          subjectArea: .06,
          goldenBalance: 0,
          environment: .5,
        ),
      );
      final supported = const CompositionRecommender().recommend(
        const SceneFeatures(subject: Point2(.618, .618), subjectConfidence: 1),
        evidence: const SceneEvidence(
          detail: 1,
          subject: Point2(.618, .618),
          subjectConfidence: 1,
          subjectArea: .06,
          goldenBalance: .95,
          environment: .65,
          leftSpace: .1,
          rightSpace: .1,
        ),
      );
      expect(supported.first.kind, CompositionKind.golden);
      expect(
        supported.first.score,
        greaterThan(
          weaker.firstWhere((p) => p.kind == CompositionKind.golden).score,
        ),
      );
    },
  );
}
