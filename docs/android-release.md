# Independent Android distribution

[English](android-release.md) | [简体中文](android-release.zh-CN.md)

For developers building and distributing their own version. Ordinary contributions need only `flutter run` or `flutter build apk --debug`.

## Configure your version

1. Change `applicationId`/`namespace` in `android/app/build.gradle.kts` and the package declaration/path of `MainActivity.kt`; set your app name, icon and `pubspec.yaml` version. The repository identifier is a development default.
2. Prepare your own store account and required registration, filing and rights documents. Check the target store's current requirements.
3. Create and back up your signing key. Copy [key.properties.example](../android/key.properties.example) to `android/key.properties` and fill it in. Keep keys and passwords out of Git.
4. Complete the [distribution materials](distribution/README.en.md) and [policy configuration](../policies/README.en.md) before building.

## Build and verify

~~~sh
flutter pub get --enforce-lockfile
flutter build appbundle --release
# When the target store requires an APK:
flutter build apk --release
~~~

Missing release signing configuration fails the build; it never falls back to a debug key. After first publication, follow the channel's requirements for identifier and signing continuity.

Verify the actual artifact's identity, version and signature. Complete the device [release checklist](release-checklist.md) before uploading under your own account. A successful build does not establish store approval.
