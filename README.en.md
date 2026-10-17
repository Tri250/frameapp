# FRAME

[简体中文](README.md) | [English](README.en.md)

A Flutter composition camera for learning and research: select a subject, compare six classic compositions, and follow live alignment guides. Photos and scene analysis stay on the device; Web provides practice mode.

![FRAME: subject selection, composition suggestions, alignment and photo guide](docs/images/frame-overview.png)

Licensed under MIT, FRAME can be modified, distributed and published by developers. Signing examples, local policy pages, release checklists and copyright-document templates help prepare a distribution. Adapt them to your needs and supply your own details; see [distribution preparation](docs/distribution/README.en.md).

## Download

| Platform | Download |
| --- | --- |
| Android | APK download link to be added |
| iOS | Installation or TestFlight link to be added |

<!-- Replace these placeholders only when a verified build is available. -->
No downloads are available here yet. Build locally using the instructions below.

## Quick start

Install **Flutter 3.47.6**, Git and Chrome:

~~~sh
git clone https://github.com/lianjiehao/frameapp.git
cd frameapp
flutter pub get --enforce-lockfile
flutter run -d chrome
~~~

For Android 7.0+, run `flutter run -d <device-id>`; add `--dart-define=DEMO_MODE=true` for mobile practice mode. iOS 15+ needs macOS, Xcode and your own development team; see [iOS setup](docs/ios-setup.md). Help and policy pages render locally.

## Develop and contribute

- [App overview](docs/app.md): features and limitations.
- [Architecture](docs/architecture.md) · [Contributing](CONTRIBUTING.en.md): source map, checks and PR workflow.
- [AI-assisted development](docs/ai-development.md): shared rules for Codex, Claude Code and Cursor; “commit code” previews all changes and waits for confirmation.
- [REA feature research](docs/rea.md): the optional `frame-rea` skill investigates software you own or are authorized to examine, then turns verified requirements into an original implementation.

## Legal and license

Code is licensed under [MIT](LICENSE); dependencies, fonts and assets retain [their own licenses](THIRD_PARTY_NOTICES.md). The project's demonstrations and research workflows support learning, research and experimentation. This purpose **does not restrict MIT's commercial-use, modification or distribution rights**.

The software is provided as is, without warranties of suitability, noninfringement or store approval. Users, researchers and distributors must verify their authority, respect copyright, privacy and image rights, and remain responsible for their own conduct. Disclaimers cannot exclude liability that applicable law does not allow to be excluded; see [usage and licensing boundaries](docs/legal.md). For security issues, see [SECURITY.md](SECURITY.md).
