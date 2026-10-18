import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/main.dart';
import 'package:framecoach/services/coach.dart';
import 'package:framecoach/services/gallery_error.dart';
import 'package:framecoach/core/composition.dart';
import 'package:framecoach/core/photo_filter.dart';
import 'package:framecoach/core/vision.dart';
import 'package:framecoach/ui/guides.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:framecoach/services/privacy.dart';
import 'tracking_test.dart' show treeView, expected, parkView, handheldView;
import 'privacy_test.dart' show TestPermissions;

Future<void> tick(WidgetTester tester, int ms) async {
  for (int i = 0; i < ms; i += 100) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      LocalConsentStore.consentKey: PolicyDocument.revision,
    }),
  );
  test(
    'small handheld motion keeps the main capture ready inside the box',
    () async {
      final frames = StreamController<GrayFrame>();
      final sensors = StreamController<AccelerometerEvent>(sync: true);
      var now = DateTime(2026, 10, 11);
      Uint8List? saved;
      final coach = CameraCoach(
        demo: true,
        previewFrames: frames.stream,
        levelEvents: sensors.stream,
        now: () => now,
        saver: (bytes, _) async => saved = bytes,
      );
      addTearDown(coach.dispose);
      await coach.initialize();
      Future<void> feed(int index) async {
        now = now.add(const Duration(milliseconds: 120));
        final direction = index.isEven ? 1.0 : -1.0;
        sensors.add(
          AccelerometerEvent(.4 * direction, 9.81 + direction, -.8, now),
        );
        final analyzed = Completer<void>();
        void changed() {
          if (!analyzed.isCompleted) analyzed.complete();
        }

        coach.addListener(changed);
        try {
          frames.add(
            treeView(panX: 14 + direction * 3, panY: -3 - direction * 2),
          );
          await analyzed.future;
        } finally {
          coach.removeListener(changed);
        }
        expect(coach.level.blocksAlignment, false);
      }

      await feed(0);
      coach.selectSubject(expected(panX: 17, panY: -5));
      await coach.confirmScene();
      coach.choosePlan(
        coach.plans.firstWhere((p) => p.kind == CompositionKind.centered),
      );
      coach.startGuidance();
      final reference = List<double>.of(
        coach.subjectLock.tracking!.reference!.values,
      );
      final revision = coach.subjectLock.revision;
      for (int i = 1; i <= 14; i++) {
        await feed(i);
        expect(coach.subjectLock.state, SubjectState.tracking);
        expect(coach.subjectLock.revision, revision);
        expect(
          coach.subjectLock.tracking!.reference!.values,
          orderedEquals(reference),
        );
        final direction = i.isEven ? 1.0 : -1.0;
        final position = expected(
          panX: 14 + direction * 3,
          panY: -3 - direction * 2,
        );
        expect(coach.subjectLock.position!.x, closeTo(position.x, .012));
        expect(coach.subjectLock.position!.y, closeTo(position.y, .012));
        expect(coach.alignment.progress, closeTo((i * .12).clamp(0, 1), .001));
        expect(coach.phase, i >= 9 ? CapturePhase.ready : CapturePhase.guiding);
      }
      coach.selectPhotoStyle(PhotoStyle.warm);
      coach.setPhotoFilterIntensity(.6);
      expect(coach.phase, CapturePhase.ready);
      expect(coach.subjectLock.state, SubjectState.tracking);
      expect(coach.subjectLock.revision, revision);
      expect(
        coach.subjectLock.tracking!.reference!.values,
        orderedEquals(reference),
      );
      await coach.takePhoto();
      expect(coach.phase, CapturePhase.captured);
      expect(coach.saved, true);
      expect(saved!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      await coach.suspend();
      await frames.close();
      await sensors.close();
    },
  );
  test(
    'an analysis finishing after its camera sample expires cannot restore a live lock',
    () async {
      final frames = StreamController<GrayFrame>(sync: true);
      var now = DateTime(2026, 10, 11);
      final coach = CameraCoach(
        demo: true,
        now: () => now,
        previewFrames: frames.stream,
      );
      addTearDown(coach.dispose);
      await coach.initialize();
      Future<void> feed(GrayFrame frame, {bool expires = false}) async {
        final analyzed = Completer<void>();
        void changed() {
          if (!analyzed.isCompleted) analyzed.complete();
        }

        coach.addListener(changed);
        frames.add(frame);
        // A synchronous stream has dispatched this sample to the worker. Advance
        // only the injected clock before its asynchronous result returns.
        if (expires) now = now.add(const Duration(seconds: 2));
        await analyzed.future;
        coach.removeListener(changed);
      }

      await feed(treeView());
      coach.selectSubject(expected());
      expect(coach.canRecommend, true);
      await feed(treeView(panX: 2), expires: true);
      expect(coach.subjectLock.state, SubjectState.lost);
      expect(coach.features.subject, isNull);
      expect(coach.canRecommend, false);
      await feed(treeView(panX: 4));
      expect(coach.subjectLock.state, SubjectState.tracking);
      expect(coach.canRecommend, true);
      expect(coach.subjectLock.position!.x, closeTo(expected(panX: 4).x, .015));
      await coach.suspend();
      await frames.close();
    },
  );
  test(
    'handheld outdoor guidance preserves selection and reaches ready after settling',
    () async {
      final frames = StreamController<GrayFrame>();
      var now = DateTime(2026, 10, 11);
      final coach = CameraCoach(
        demo: true,
        now: () => now,
        previewFrames: frames.stream,
      );
      addTearDown(coach.dispose);
      await coach.initialize();
      expect(coach.initialized, true);
      final source = await parkView();
      Future<void> feed(GrayFrame frame) async {
        now = now.add(const Duration(milliseconds: 120));
        final analyzed = Completer<void>();
        void onAnalyzed() {
          if (!analyzed.isCompleted) analyzed.complete();
        }

        coach.addListener(onAnalyzed);
        try {
          frames.add(frame);
          await analyzed.future;
        } finally {
          coach.removeListener(onAnalyzed);
        }
      }

      await feed(source);
      const anchor = Point2(.2, .72);
      coach.selectSubject(anchor);
      await coach.confirmScene();
      expect(coach.phase, CapturePhase.recommending);
      coach.choosePlan(
        coach.plans.firstWhere((p) => p.kind == CompositionKind.thirds),
      );
      coach.startGuidance();
      final target = coach.plan!.target;
      final reference = coach.subjectLock.tracking!.reference;

      void expectLive(double dx, double dy) {
        expect(coach.subjectLock.state, SubjectState.tracking);
        expect(coach.subjectLock.tracking!.reference, same(reference));
        expect(coach.plan!.target, same(target));
        expect(coach.features.subject, isNotNull);
        expect(coach.features.subject!.x, closeTo(anchor.x - dx / 192, .012));
        expect(coach.features.subject!.y, closeTo(anchor.y - dy / 256, .012));
      }

      // Tracking stays visible across alternating directions and blur.
      for (int i = 1; i <= 12; i++) {
        final dx = math.sin(i * 1.2) * 4, dy = math.cos(i * .8) * 3;
        await feed(
          handheldView(
            source,
            dx: dx,
            dy: dy,
            blur: i.isOdd ? 3 : 0,
            gain: i.isOdd ? .8 : 1,
          ),
        );
        expectLive(dx, dy);
        expect(coach.phase, CapturePhase.guiding);
      }
      final dx = (anchor.x - target.x) * 192;
      final dy = (anchor.y - target.y) * 256;
      for (int i = 1; i <= 10; i++) {
        await feed(handheldView(source, dx: dx * i / 10, dy: dy * i / 10));
        expectLive(dx * i / 10, dy * i / 10);
      }
      // The final approach already contributes while the target is in the box.
      // Keeping it there must continue that hold without restarting the timer.
      final initialProgress = coach.alignment.progress;
      for (int i = 1; i <= 10; i++) {
        await feed(handheldView(source, dx: dx, dy: dy));
        final progress = (initialProgress + i * .12).clamp(0, 1);
        expect(coach.alignment.progress, closeTo(progress, .001));
        expect(
          coach.phase,
          progress >= 1 ? CapturePhase.ready : CapturePhase.guiding,
        );
      }
      expect(coach.phase, CapturePhase.ready);
      expect(coach.alignment.message, '可以拍照了');
      expectLive(dx, dy);

      await feed(
        GrayFrame(192, 256, Uint8List(192 * 256)..fillRange(0, 192 * 256, 110)),
      );
      expect(coach.subjectLock.state, SubjectState.lost);
      expect(coach.features.subject, isNull);
      expect(coach.phase, CapturePhase.guiding);
      expect(coach.alignment.ready, false);
      expect(coach.plan!.target, same(target));
      await coach.suspend();
      await frames.close();
    },
  );
  for (final kind in [CompositionKind.centered, CompositionKind.symmetry]) {
    testWidgets(
      'main shutter captures ${kind.name} with continuous tilted sensor events',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final frames = StreamController<GrayFrame>();
        final sensors = StreamController<AccelerometerEvent>();
        Uint8List? saved;
        final coach = CameraCoach(
          demo: true,
          previewFrames: frames.stream,
          levelEvents: sensors.stream,
          now: tester.binding.clock.now,
          saver: (bytes, _) async => saved = bytes,
        );
        await tester.pumpWidget(
          FrameApp(
            coach: coach,
            permissionBackend: TestPermissions()..photos = true,
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tick(tester, 300);
        void sensor({bool shaking = false}) {
          final scale = shaking ? 1.6 : 1.0;
          sensors.add(
            kind == CompositionKind.centered
                ? AccelerometerEvent(
                    1.04 * scale,
                    9.16 * scale,
                    -3.35 * scale,
                    tester.binding.clock.now(),
                  )
                : AccelerometerEvent(
                    0,
                    6.936 * scale,
                    6.936 * scale,
                    tester.binding.clock.now(),
                  ),
          );
        }

        Future<void> feed({bool hidden = false}) async {
          sensor();
          frames.add(treeView(panX: 14, panY: -3, hidden: hidden));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 120)),
          );
          await tick(tester, 200);
        }

        await feed();
        coach.selectSubject(const Point2(.5, .5));
        await feed();
        await tester.tap(find.byKey(const Key('confirm-scene')));
        await tick(tester, 400);
        coach.choosePlan(coach.plans.firstWhere((p) => p.kind == kind));
        await tester.pump();
        await tester.tap(find.byKey(const Key('start-guidance')));
        expect(coach.phase, CapturePhase.guiding);
        if (kind == CompositionKind.centered) {
          expect(coach.level.angle, closeTo(-6.5, .5));
        } else {
          expect(coach.level.label, '俯拍');
          expect(coach.features.symmetry, lessThan(.6));
        }
        for (int i = 0; i < 7; i++) {
          await feed();
        }
        expect(
          coach.phase,
          CapturePhase.ready,
          reason: coach.alignment.message,
        );
        expect(coach.alignment.advice, isNotNull);
        // The actual sensor callback must not undo readiness between image frames.
        sensor();
        await tester.pump();
        expect(coach.phase, CapturePhase.ready);
        expect(
          tester
              .widget<GestureDetector>(find.byKey(const Key('shutter')))
              .onTap,
          isNotNull,
        );
        // Real motion still revokes readiness immediately; stable fresh images
        // must earn it again before the main shutter can take the photograph.
        sensor(shaking: true);
        await tester.pump();
        expect(coach.phase, CapturePhase.guiding);
        expect(
          tester
              .widget<GestureDetector>(find.byKey(const Key('shutter')))
              .onTap,
          isNull,
        );
        for (int i = 0; i < 8; i++) {
          await feed();
        }
        expect(
          coach.phase,
          CapturePhase.ready,
          reason: coach.alignment.message,
        );
        await tester.tap(find.byKey(const Key('shutter')));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tick(tester, 400);
        expect(coach.phase, CapturePhase.captured);
        expect(coach.saved, true);
        expect(saved!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        unawaited(frames.close());
        unawaited(sensors.close());
        await tester.pump();
      },
    );
  }
  testWidgets(
    'timed shutter cycles, counts down while ready, cancels on a second tap or lost readiness, and fires through the ready gate',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final frames = StreamController<GrayFrame>();
      final sensors = StreamController<AccelerometerEvent>();
      Uint8List? saved;
      final coach = CameraCoach(
        demo: true,
        previewFrames: frames.stream,
        levelEvents: sensors.stream,
        now: tester.binding.clock.now,
        saver: (bytes, _) async => saved = bytes,
      );
      await tester.pumpWidget(
        FrameApp(
          coach: coach,
          permissionBackend: TestPermissions()..photos = true,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tick(tester, 300);
      void sensor({bool shaking = false}) {
        final scale = shaking ? 1.6 : 1.0;
        sensors.add(
          AccelerometerEvent(
            1.04 * scale,
            9.16 * scale,
            -3.35 * scale,
            tester.binding.clock.now(),
          ),
        );
      }

      Future<void> feed() async {
        sensor();
        frames.add(treeView(panX: 14, panY: -3));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tick(tester, 200);
      }

      // A live camera keeps delivering frames during a countdown, so every
      // simulated second feeds four fresh frames before crossing the tick
      // deadline. Frameless gaps trip the stale-frame watchdog and revoke
      // readiness, which is the intended contract, not a bug.
      Future<void> liveSecond() async {
        for (int i = 0; i < 4; i++) {
          await feed();
        }
        await tester.pump(const Duration(milliseconds: 300));
      }

      await feed();
      coach.selectSubject(const Point2(.5, .5));
      await feed();
      await tester.tap(find.byKey(const Key('confirm-scene')));
      await tick(tester, 400);
      coach.choosePlan(
        coach.plans.firstWhere((p) => p.kind == CompositionKind.centered),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-guidance')));
      for (int i = 0; i < 7; i++) {
        await feed();
      }
      expect(coach.phase, CapturePhase.ready, reason: coach.alignment.message);
      // Off → 3s → 10s → off cycle, independent of the live countdown.
      await tester.tap(find.byKey(const Key('countdown-toggle')));
      await tester.pump();
      expect(coach.countdownSeconds, 3);
      await tester.tap(find.byKey(const Key('countdown-toggle')));
      await tester.pump();
      expect(coach.countdownSeconds, 10);
      await tester.tap(find.byKey(const Key('countdown-toggle')));
      await tester.pump();
      expect(coach.countdownSeconds, 0);
      await tester.tap(find.byKey(const Key('countdown-toggle')));
      await tester.pump();
      expect(coach.countdownSeconds, 3);
      // Starting the countdown shows the overlay and steps once per second.
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pump();
      expect(coach.countdownRemaining, 3);
      expect(find.byKey(const Key('countdown-overlay')), findsOneWidget);
      await liveSecond();
      expect(coach.countdownRemaining, 2);
      await liveSecond();
      expect(coach.countdownRemaining, 1);
      expect(find.byKey(const Key('countdown-overlay')), findsOneWidget);
      // A second shutter tap cancels without taking a photograph.
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pump();
      expect(coach.countdownRemaining, isNull);
      expect(coach.phase, CapturePhase.ready);
      expect(saved, isNull);
      // Losing readiness during the countdown stops it.
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pump();
      expect(coach.countdownRemaining, 3);
      sensor(shaking: true);
      await tester.pump();
      expect(coach.phase, CapturePhase.guiding);
      await tester.pump(const Duration(seconds: 1));
      expect(coach.countdownRemaining, isNull);
      // The fired timer still passes the normal ready gate before capturing.
      for (int i = 0; i < 10; i++) {
        await feed();
      }
      expect(coach.phase, CapturePhase.ready, reason: coach.alignment.message);
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.pump();
      expect(coach.countdownRemaining, 3);
      await liveSecond();
      expect(coach.countdownRemaining, 2);
      await liveSecond();
      expect(coach.countdownRemaining, 1);
      await liveSecond();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tick(tester, 400);
      expect(coach.countdownRemaining, isNull);
      expect(coach.phase, CapturePhase.captured);
      expect(coach.saved, true);
      expect(saved!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(coach.shotFeedback, isNotNull);
      expect(coach.shotFeedback!.score, greaterThan(0));
      await tester.pump();
      expect(find.byKey(const Key('shot-feedback')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(frames.close());
      unawaited(sensors.close());
      await tester.pump();
    },
  );
  testWidgets(
    'recommendation requires a user-selected live subject and a new selection after reset',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final frames = StreamController<GrayFrame>();
      final coach = CameraCoach(
        demo: true,
        now: tester.binding.clock.now,
        previewFrames: frames.stream,
      );
      await tester.pumpWidget(
        FrameApp(
          coach: coach,
          permissionBackend: TestPermissions()..photos = true,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tick(tester, 300);
      final confirm = find.byKey(const Key('confirm-scene'));
      bool enabled() => tester.widget<FilledButton>(confirm).onPressed != null;
      Future<void> feed(GrayFrame frame) async {
        frames.add(frame);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tick(tester, 200);
      }

      Future<void> select(Point2 point) async {
        final viewport = find.byKey(const Key('viewfinder'));
        await tester.tapAt(
          tester.getTopLeft(viewport) +
              Offset(
                point.x * tester.getSize(viewport).width,
                point.y * tester.getSize(viewport).height,
              ),
        );
        await tester.pump();
      }

      // Loading an image or detecting a salient region never selects it for the user.
      expect(coach.initialized, true);
      expect(coach.subjectLock.state, SubjectState.unselected);
      expect(enabled(), false);
      await feed(treeView());
      expect(coach.features.subject, isNotNull);
      expect(enabled(), false);
      await coach.confirmScene();
      expect(coach.phase, CapturePhase.framing);
      expect(coach.plans, isEmpty);
      expect(coach.error, contains('先点选'));

      await feed(
        GrayFrame(192, 256, Uint8List(192 * 256)..fillRange(0, 192 * 256, 110)),
      );
      await select(const Point2(.5, .5));
      expect(coach.subjectLock.state, SubjectState.needsDetail);
      expect(enabled(), false);
      await coach.confirmScene();
      expect(coach.phase, CapturePhase.framing);
      expect(coach.plans, isEmpty);

      await feed(treeView());
      // A failed selection cannot become a different automatically detected subject.
      expect(enabled(), false);
      await select(expected());
      expect(coach.subjectLock.state, SubjectState.tracking);
      expect(enabled(), true);
      await tick(tester, 1200);
      expect(coach.subjectLock.state, SubjectState.lost);
      expect(enabled(), false);
      await coach.confirmScene();
      expect(coach.phase, CapturePhase.framing);
      expect(coach.plans, isEmpty);

      await feed(treeView());
      expect(enabled(), true);
      await tester.tap(confirm);
      await tester.pump();
      expect(enabled(), false);
      await tick(tester, 400);
      expect(coach.phase, CapturePhase.recommending);
      expect(coach.plans, isNotEmpty);
      coach.resetFraming();
      await tester.pump();
      expect(coach.subjectLock.state, SubjectState.unselected);
      expect(enabled(), false);
      await coach.confirmScene();
      expect(coach.phase, CapturePhase.framing);
      expect(coach.plans, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(frames.close());
      await tester.pump();
    },
  );
  testWidgets(
    'real demo pixels complete recommendation, alignment, capture, and save retry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int attempts = 0;
      Uint8List? saved;
      final coach = CameraCoach(
        demo: true,
        now: tester.binding.clock.now,
        saver: (bytes, _) async {
          attempts++;
          if (attempts == 1) {
            throw const PhotoSaveException('请在系统设置中允许相册权限，再点「重新保存」。');
          }
          saved = bytes;
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('app-preview'),
          child: FrameApp(
            coach: coach,
            permissionBackend: TestPermissions()..photos = true,
          ),
        ),
      );
      if (const bool.fromEnvironment('EXPORT_PREVIEW')) {
        await tester.runAsync(() => loadAppFonts());
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tick(tester, 600);
      expect(coach.initialized, true);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('EXPORT_PREVIEW')) {
        await savePreview(tester, '../framecoach-framing.png');
        await tester.tap(find.byTooltip('拍照指南'));
        await tick(tester, 400);
        await savePreview(tester, '../framecoach-help.png');
        await tester.tapAt(const Offset(10, 10));
        await tick(tester, 400);
      }
      final viewport = find.byKey(const Key('viewfinder'));
      // The user chooses the person in the park photo, independently of saliency.
      final crop = coach.demoCrop;
      final seed = Point2(
        (665 - crop.left) / crop.width,
        (475 - crop.top) / crop.height,
      );
      await tester.tapAt(
        tester.getTopLeft(viewport) +
            Offset(
              seed.x * tester.getSize(viewport).width,
              seed.y * tester.getSize(viewport).height,
            ),
      );
      await tick(tester, 400);
      expect(coach.subjectLock.state, SubjectState.tracking);
      expect(subjectPainter(tester).subjectPosition, isNotNull);
      await tester.tap(find.byKey(const Key('confirm-scene')));
      await tick(tester, 500);
      expect(coach.phase, CapturePhase.recommending);
      expect(subjectPainter(tester).subjectPosition, isNotNull);
      expect(find.text('适合度'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('selected-suitability')),
          matching: find.text('${(coach.plan!.score * 100).round()}'),
        ),
        findsOneWidget,
      );
      if (const bool.fromEnvironment('EXPORT_PREVIEW')) {
        await savePreview(tester, '../framecoach-recommendation.png');
        await tester.tap(find.text('全部构图 ↗'));
        await tick(tester, 400);
        await savePreview(tester, '../framecoach-methods.png');
        await tester.tapAt(const Offset(10, 10));
        await tick(tester, 400);
      }
      coach.choosePlan(
        coach.plans.firstWhere((p) => p.kind == CompositionKind.thirds),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('start-guidance')));
      await tick(tester, 300);
      expect(coach.phase, CapturePhase.guiding);
      await tester.tap(find.byKey(const Key('demo-align')));
      await tick(tester, 3200);
      expect(
        coach.phase,
        CapturePhase.ready,
        reason:
            'subject=${coach.features.subject?.x},${coach.features.subject?.y}; target=${coach.plan?.target.x},${coach.plan?.target.y}; ${coach.alignment.message}; horizon=${coach.features.horizonAngle} confidence=${coach.features.horizonConfidence}',
      );
      if (const bool.fromEnvironment('EXPORT_PREVIEW')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('app-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          await File('../framecoach-preview.png').writeAsBytes(bytes);
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const Key('shutter')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tick(tester, 500);
      expect(coach.phase, CapturePhase.captured);
      expect(coach.photo, isNotNull);
      expect(coach.saved, false);
      expect(coach.saveError, contains('相册权限'));
      await tester.tap(find.byKey(const Key('next-photo')));
      await tick(tester, 300);
      expect(coach.saved, true);
      expect(saved!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(tester.takeException(), isNull);
      final selectedPosition = coach.subjectLock.position!;
      coach.resetFraming();
      await tick(tester, 400);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirm-scene')))
            .onPressed,
        isNull,
      );
      await tester.tapAt(
        tester.getTopLeft(viewport) +
            Offset(
              selectedPosition.x * tester.getSize(viewport).width,
              selectedPosition.y * tester.getSize(viewport).height,
            ),
      );
      await tick(tester, 200);
      await tester.tap(find.byKey(const Key('confirm-scene')));
      await tick(tester, 400);
      expect(coach.phase, CapturePhase.recommending);
      await coach.suspend();
      await tester.pump();
      expect(coach.phase, CapturePhase.framing);
      expect(coach.plan, isNull);
      expect(coach.initialized, false);
      await tester.runAsync(coach.initialize);
      await tick(tester, 400);
      expect(coach.initialized, true);
      expect(coach.phase, CapturePhase.framing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'camera frames move the selected marker in the UI and real loss withdraws the live lock',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final frames = StreamController<GrayFrame>(sync: true);
      final coach = CameraCoach(
        demo: true,
        now: tester.binding.clock.now,
        previewFrames: frames.stream,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('app-preview'),
          child: FrameApp(
            coach: coach,
            permissionBackend: TestPermissions()..photos = true,
          ),
        ),
      );
      if (const bool.fromEnvironment('EXPORT_PREVIEW')) {
        await tester.runAsync(() => loadAppFonts());
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tick(tester, 300);
      Future<void> feedBatch(List<GrayFrame> samples) async {
        var previous = coach.features;
        var results = 0;
        // A synchronous burst starts the first sample and keeps only the last
        // pending sample. Wait for both results without advancing sample time.
        final expectedResults = samples.length == 1 ? 1 : 2;
        void onAnalyzed() {
          if (identical(previous, coach.features)) return;
          previous = coach.features;
          results++;
        }

        coach.addListener(onAnalyzed);
        try {
          for (final frame in samples) {
            frames.add(frame);
          }
          final deadline = Stopwatch()..start();
          while (results < expectedResults &&
              deadline.elapsed < const Duration(seconds: 10)) {
            // Worker completion runs outside the widget clock; pump its queued
            // callback before checking the observable analysis result again.
            await tester.runAsync(() => Future<void>(() {}));
            await tester.pump();
          }
          expect(
            results,
            expectedResults,
            reason: 'All selected samples analyzed',
          );
        } finally {
          coach.removeListener(onAnalyzed);
        }
        await tester.pumpAndSettle();
      }

      Future<void> feed(GrayFrame frame) => feedBatch([frame]);

      await feed(treeView());
      final viewfinder = find.byKey(const Key('viewfinder'));
      final first = expected();
      await tester.tapAt(
        tester.getTopLeft(viewfinder) +
            Offset(
              first.x * tester.getSize(viewfinder).width,
              first.y * tester.getSize(viewfinder).height,
            ),
      );
      await tester.pump();
      expect(coach.subjectLock.state, SubjectState.tracking);
      final initial = subjectPainter(tester).subjectPosition!;
      // Rapid arrivals must retain the newest image while an isolate is busy.
      await feedBatch([
        for (final pan in [2.0, 4.0, 6.0, 8.0]) treeView(panX: pan),
      ]);
      expect(
        subjectPainter(tester).subjectPosition!.x,
        closeTo(expected(panX: 8).x, .025),
      );
      for (int i = 1; i <= 5; i++) {
        await feed(treeView(panX: i * 7, panY: -i * 4));
        final marker = subjectPainter(tester).subjectPosition!;
        final target = expected(panX: i * 7, panY: -i * 4);
        expect(marker.x, closeTo(target.x, .025));
        expect(marker.y, closeTo(target.y, .025));
        expect(subjectPainter(tester).subjectTracked, true);
      }
      final marker = subjectPainter(tester).subjectPosition!;
      expect(marker.x, lessThan(initial.x - .15));
      final last = coach.subjectLock.position!;
      await feed(treeView(panX: 35, panY: -20, hidden: true));
      expect(coach.subjectLock.state, SubjectState.lost);
      expect(subjectPainter(tester).subjectTracked, false);
      expect(subjectPainter(tester).subjectPosition, isNull);
      expect(coach.subjectLock.position!.x, closeTo(last.x, .001));
      expect(find.text('主体跟丢了'), findsOneWidget);
      expect(find.text('请点一下主体，重新锁定'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirm-scene')))
            .onPressed,
        isNull,
      );
      await coach.confirmScene();
      expect(coach.phase, CapturePhase.framing);
      expect(coach.plans, isEmpty);
      await tester.pump();
      if (const bool.fromEnvironment('EXPORT_PREVIEW')) {
        await savePreview(tester, '../framecoach-tracking-lost.png');
      }
      await feed(treeView(panX: 40, panY: -20));
      expect(coach.subjectLock.state, SubjectState.tracking);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('confirm-scene')))
            .onPressed,
        isNotNull,
      );
      expect(
        subjectPainter(tester).subjectPosition!.x,
        closeTo(expected(panX: 40, panY: -20).x, .025),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(frames.close());
      await tester.pump();
    },
  );
}

GuidePainter subjectPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<GuidePainter>()
    .single;

Future<void> loadAppFonts() async {
  for (final pair in [
    ('FrameSans', 'assets/fonts/FrameSans-Regular.ttf'),
    ('Editorial', 'assets/fonts/DMSerifDisplay-Regular.ttf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    final loader = FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2));
    await loader.load();
  }
}

Future<void> savePreview(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('app-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    await File(path).writeAsBytes(bytes);
    image.dispose();
  });
}
