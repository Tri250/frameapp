# Maintainer workflow

[English](community-governance.md) | [简体中文](community-governance.zh-CN.md)

## Merge and release

Use short-lived branches and focused PRs targeting `main`. External contributors work in forks. Review product fit, implementation, regression evidence and platform impact; resolve discussions, then squash merge with author/co-author attribution. A merge is not a store release.

Independent distributors use their own identities and credentials. For distribution: choose a candidate SHA, run Android/iOS device checks, increment the version/build in `pubspec.yaml`, create an immutable `vX.Y.Z` tag after acceptance, and build/sign from that commit. Record the SHA, build number, artifact hashes and store status. Use the [release checklist](release-checklist.md). Signing and store credentials stay outside Git and ordinary PR workflows.

## Enable repository enforcement

Committed templates are not proof that GitHub rules are active. Verify the current Settings and Actions results before opening collaboration or granting write access.

1. Push and validate [.github/workflows](../.github/workflows), including the pinned Flutter/Xcode build environment.
2. Import [.github/rulesets/owner-branches.json](../.github/rulesets/owner-branches.json), then [.github/rulesets/main.json](../.github/rulesets/main.json); enable both when the repository's visibility/plan permits.
3. Verify required checks: `Code quality`, `Android build`, `iOS build` and `Contributor page ownership`. Keep deletion/force-push protection, resolved discussions and review requirements enabled.
4. Test ordinary external PRs, protected-path external PRs and owner-branch PRs. Verify that another write user cannot push to `owner-contributors`.

The main template has no bypass and requires an approving Code Owner other than the author. Before enabling it, ensure an eligible second reviewer exists for owner-authored PRs, including explicit path rules. A single maintainer cannot approve their own PR. CODEOWNERS alone does not enforce merge protection. This repository does not currently configure a merge queue.

## Owner-maintained content

`@lianjiehao` alone submits changes to contributor records, scores, pages and shared publishing machinery. The exact protected paths and user ID are in [.github/contributors-ownership.json](../.github/contributors-ownership.json), including all of `tools/` and `.github/`. Others request corrections through Issues; request a private channel when needed.

The ownership check verifies the PR author, source repository, changed paths and active protection of the owner's `owner-contributors` branch. Approval, commit email, editable attribution fields or the person rerunning CI cannot bypass identity checks. Renames/deletions are checked too. Owners must submit protected changes from that branch in the main repository; do not weaken the policy to make a PR pass.

The `pull_request_target` ownership workflow reads PR metadata and runs trusted base-branch code. It must never execute PR code. Regular CI has read-only permissions and no signing secrets. Dependabot changes under `.github/` must be reapplied by the owner through this same flow.

## Contribution recognition

Recognize accepted work using public Issue/PR evidence, not lines, commits, stars or comment counts. The owner confirms value and records the result in `policies/community.json`.

| Points | Accepted result |
| --- | --- |
| 1 | Small correction, copy or documentation improvement |
| 3 | Reproducible fix, useful test/device verification or modest UX improvement |
| 5 | Verified feature improvement or significant reliability/performance fix |
| 8 | A substantial change agreed and split before implementation, then accepted |

The same result earns credit once. Shared work uses agreed shares totaling 1; reverted work is marked `reverted` and removed from valid totals. Drafts, unmerged PRs and automated dependency updates do not automatically earn personal credit. The page shows cumulative and recent 90-day scores, with ties allowed. Recognition is not a promise of payment or equity.

Public listing is opt-in and uses only a public GitHub login or chosen display name. Preserve normal commit attribution even if a contributor opts out. Confirm display consent and co-authors before publication. Corrections, score disputes and removal requests go through an Issue or a privately agreed channel.

## Policy and contributor documents

The owner maintains shared policy text and contributor records. `tools/verify_contributions.py` checks public contribution evidence. Generate and review the app documents together with their sources; see [local policy pages](../policies/README.en.md).
