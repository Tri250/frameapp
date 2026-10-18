import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/core/composition.dart';
import 'package:framecoach/core/scene_evidence.dart';
import 'package:framecoach/core/vision.dart';

GrayFrame shapedFrame(int value, {int Function(int x, int y)? at}) {
  const w = 96, h = 128;
  final pixels = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      pixels[y * w + x] = at == null ? value : at(x, y);
    }
  }
  return GrayFrame(w, h, pixels);
}

void main() {
  test('brightness distribution is measured without any semantic label', () {
    final dim = SceneEvidence.measure(shapedFrame(30), const SceneFeatures());
    expect(dim.meanBrightness, closeTo(30, .5));
    expect(dim.highlightShare, 0);
    expect(dim.shadowShare, 0);

    final night = SceneEvidence.measure(shapedFrame(8), const SceneFeatures());
    expect(night.meanBrightness, lessThan(55));
    expect(night.shadowShare, greaterThan(.99));

    final sky = SceneEvidence.measure(
      shapedFrame(0, at: (_, y) => y < 64 ? 250 : 110),
      const SceneFeatures(),
    );
    expect(sky.meanBrightness, greaterThan(135));
    expect(sky.highlightShare, closeTo(.5, .05));

    final harsh = SceneEvidence.measure(
      shapedFrame(0, at: (_, y) => y < 51 ? 248 : 8),
      const SceneFeatures(),
    );
    expect(harsh.highlightShare, closeTo(.4, .05));
    expect(harsh.shadowShare, closeTo(.6, .05));
  });

  test('alignment results quantify the remaining distance to the target', () {
    final tracker = AlignmentTracker();
    final plan = CompositionPlan(
      CompositionKind.thirds,
      .6,
      const Point2(.5, .5),
      1 / 3,
      'x',
    );
    final features = SceneFeatures(
      subject: const Point2(.4, .5),
      subjectConfidence: .9,
    );
    final result = tracker.update(plan, features, DateTime(2026, 10, 18));
    expect(result.valid, true);
    expect(result.distance, closeTo(.075, .001));
    const none = AlignmentResult(false, 0, 0, 'x', false);
    expect(none.distance, 0);
  });
}
