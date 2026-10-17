# Contributing to FRAME

[简体中文](CONTRIBUTING.md) | [English](CONTRIBUTING.en.md)

We welcome bug reports, fixes, tests, device verification, design and documentation translations. Chinese and English are both welcome. Start with an Issue for a substantial feature or architectural change; a small, clear fix can go straight to a PR.

## Open a pull request

1. Fork the repository, branch from the latest `main`, and use a descriptive branch name such as `fix/save-retry` or `feat/guide-copy`.
2. Keep one issue per PR. Read [architecture](docs/architecture.md) and [AGENTS.md](AGENTS.md); follow the surrounding implementation.
3. Add regression coverage for changed behavior. Attach screenshots for UI changes and device results for camera, permissions, orientation, saving or lifecycle changes. State untested platforms explicitly.
4. Run the [checks below](#checks). Use the [PR template](.github/pull_request_template.md) to describe the problem, resulting behavior, checks and known limitations. Link the Issue if one exists.
5. Address review feedback and rerun affected checks after changes. Never commit signing files, credentials, private photos, build output or unrelated refactors.

For first contributions, documentation, reproducible bug reports, small regressions and device testing are useful entry points. Use an existing `good first issue` label when available, or describe the scope in an Issue before starting.

## How changes are accepted

**PR → automated checks → maintainer review → revisions → squash merge into `main` → release testing.**

CI checks formatting, analysis, Flutter/Python tests, documentation links, generated pages, final APK permissions and Android/iOS builds. Passing checks is necessary when required by repository settings, but does not itself approve a change. The maintainer evaluates product fit, correctness, clear scope, maintainability and evidence. Open review discussions must be resolved; the maintainer explains requested changes or why a proposal is not accepted in the PR. There is no guaranteed merge or release date.

Capture and permission changes need device evidence before distribution. Developers may distribute under MIT using their own accounts, signing and operator details; see [independent distribution](docs/distribution/README.en.md). A merge grants no authority to act for the author. GitHub enforcement must be enabled server-side; see [maintainer governance](docs/community-governance.md).

## Checks

Use Flutter 3.47.6 from the repository root:

~~~sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
python3 -m unittest discover -s tools/tests
python3 tools/check_docs.py
~~~

After policy source changes, run `python3 tools/build_policy_pages.py` and include synchronized outputs. CI also builds an Android debug APK and unsigned iOS app; see the [workflow](.github/workflows/ci.yml).

## AI-assisted contributions

Codex, Claude Code and Cursor are supported through the shared [project rules](AGENTS.md). See the [AI guide](docs/ai-development.md) for setup and a task prompt.

You remain responsible for every submitted line. Review the diff, understand the behavior, check dependency/API claims against the installed version, and report checks actually run. Do not submit fabricated tests, screenshots, benchmark results or device validation. Briefly note significant AI assistance and how you reviewed it in the PR; raw chat logs are not required. Never send secrets or private user data to an assistant.

## Owner-maintained paths

The ownership policy reserves `.github/`, `tools/`, contributor data/pages, policy configuration and certain shared generated files for `@lianjiehao`. The exact list is [.github/contributors-ownership.json](.github/contributors-ownership.json). Approval does not exempt another author's PR from the ownership check.

For improvements in these paths, file an Issue with the proposed change. Policy text is also generated through owner-maintained tooling; do not edit HTML/Dart output directly. The owner applies accepted changes through the `owner-contributors` branch flow. Ordinary app code and these developer documents remain normal contribution targets.

## Attribution and license

Contributions are submitted under the project's [MIT license](LICENSE); you must have the right to contribute the code and assets. Dependencies and fonts keep their own licenses, listed in [Third-party notices](THIRD_PARTY_NOTICES.md).

The PR retains its author. For work completed together, include `Co-authored-by: Name <GitHub-linked email>` so the squash commit preserves each human co-author. Contributor-page display is optional and requires consent; only public GitHub names or chosen display names are listed. Accepted code and other adopted work can receive recognition under [governance](docs/community-governance.md). Credit is based on accepted work, not line counts or splitting commits.

For corrections or removal from the optional contributor page, open an Issue; if privacy is needed, request a private channel without posting personal details. Report security issues privately through [SECURITY.md](SECURITY.md).
