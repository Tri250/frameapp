# Release checklist

[English](release-checklist.md) | [简体中文](release-checklist.zh-CN.md)

For developers verifying a distribution. Complete the [distribution materials](distribution/README.en.md) first.

Version/build: · Tag/full SHA: · Maintainer/date:

- [ ] Required CI checks pass for the release commit; review discussions are resolved.
- [ ] Version/build increased; release notes describe behavior changes and limitations.
- [ ] Android and iOS device evidence records model, OS, reviewer and result.
- [ ] Subject selection, movement, loss/reselection, low light, shaking and fast pans checked.
- [ ] Main/direct shutter, front/rear camera, crop/orientation and gallery save checked.
- [ ] Permission refusal/retry, storage failure and save retry checked.
- [ ] Before-consent inactivity, withdrawal, background/resume and policy return checked.
- [ ] Own operator/contact details filled in; local policy rendering and navigation checked.
- [ ] Release signing belongs to the independent distributor; no debug signing or credentials in artifacts.
- [ ] Build matches the accepted SHA; hashes, version and signing identity recorded.
- [ ] MIT and third-party notices retained; new assets have redistribution permission.
- [ ] Store/internal testing and required listing/privacy disclosures complete.
- [ ] Authors/co-authors preserved; optional contributor listing has consent.
- [ ] Immutable release tag, rollout owner and follow-up fix plan recorded.

## Before first public release

- [ ] Inspect tracked files and Git history for secrets, private material and signing data.
- [ ] Keep completed store/copyright filings and generated builds out of Git; blank templates may be shared.
- [ ] Verify source/assets licensing and the developer README and paired English/Chinese guides.
- [ ] Enable and test GitHub rulesets and required checks; see [governance](community-governance.md).
