# iOS development

[English](ios-setup.md) | [简体中文](ios-setup.zh-CN.md)

Requires macOS, full Xcode and Flutter 3.47.6. The project targets iOS 15+ and uses Swift Package Manager. CI selects Xcode 26.3; use Xcode compatible with your Mac and target device, then verify `flutter doctor -v`.

## Build and run

1. Finish Xcode's first launch and platform-component installation. Select it as the active developer directory if needed.
2. From the repository root, run:

~~~sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter devices
open ios/Runner.xcworkspace
~~~

3. In Runner → Signing & Capabilities, select your own development team and, when needed, a unique bundle identifier. Do not use the maintainer's team or commit your local signing changes.
4. Connect and trust your iPhone, enable Developer Mode if required, then run `flutter run -d <device-id>`. On-device trust and signing must be completed using your own account.
5. Without signing, a build check is `flutter build ios --release --no-codesign`; it does not produce an installable store release.

## Permission plugin

Keep the existing camera, add-only photos and motion usage descriptions in `ios/Runner/Info.plist`. When building through Flutter, the permission plugin reads this file. If launching directly from Xcode and camera authorization fails, configure the build environment's `PERMISSION_HANDLER_INFO_PLIST` to the absolute path of your checkout's `ios/Runner/Info.plist`, then resolve Swift packages again. Do not add microphone or photo-library read permissions to bypass the problem.

## Verify on a phone

Check first-launch consent, refusal and explicit retry; real preview and front/rear orientation; selected-subject movement and loss; shutter and gallery save; failed-save retry; background/resume; policy-page return; and consent withdrawal. Record model, iOS version, commit and observed results in the PR. Simulator and unsigned build success are not camera or App Store validation.

Distributors use their own team, bundle ID, signing and App Store Connect account; complete the [distribution templates](distribution/README.en.md) and [release checklist](release-checklist.md).
