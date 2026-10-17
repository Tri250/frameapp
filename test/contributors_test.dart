import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framecoach/main.dart';
import 'package:framecoach/services/coach.dart';
import 'package:framecoach/services/privacy.dart';
import 'package:framecoach/ui/privacy_flow.dart';
import 'privacy_test.dart' show MemoryStore;

void main() {
  testWidgets('contributors entry opens page and pauses camera until return', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final consent = PrivacyConsent(store: MemoryStore(PolicyDocument.revision));
    final coach = CameraCoach(demo: true);
    await tester.pumpWidget(FrameApp(coach: coach, consent: consent));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(coach.initialized, true);
    await tester.tap(find.byTooltip('拍照指南'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final entry = find.byKey(const Key('show-contributors'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(coach.initialized, false);
    final page = tester.widget<PolicyPage>(find.byType(PolicyPage));
    expect(page.document, PolicyDocument.contributors);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byType(SelectableText), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
    expect(coach.initialized, false);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(coach.initialized, true);
    await tester.pumpWidget(const SizedBox());
    consent.dispose();
  });
}
