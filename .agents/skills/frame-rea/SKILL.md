---
name: frame-rea
description: Use REA (morluto/rea) to research an authorized application's feature and implement an original equivalent in FRAME. Use when the user explicitly requests REA or authorized reverse-engineering research for a FRAME feature; not for ordinary feature work without a reference target.
---

# REA feature research for FRAME

Read [AGENTS.md](../../../AGENTS.md), [architecture](../../../docs/architecture.md), [legal boundaries](../../../docs/legal.md), and the relevant source/tests. This skill guides optional development research; REA is not an app runtime dependency. Respond in the user's language.

## Establish the target and scope

Identify the feature, target/version, local artifact or public documentation, authorization basis and requested operations. Existing explicit authorization is sufficient for its stated scope; do not ask again. Possession, purchase, public availability, or the label “research” alone is not permission to reverse engineer or redistribute. If scope is missing, ask only for the necessary information and continue independent FRAME code inspection. Do not analyze the uncertain target meanwhile.

Do not help crack licensing, bypass payment/DRM/access controls, obtain keys, remove attribution, or extract private data. Offer public documentation, licensed examples or a user-authored behavioral specification instead. Record unresolved rights questions without making legal conclusions or promising immunity.

## Use the available REA installation

Follow the [official REA setup](https://github.com/morluto/rea/blob/main/docs/installation.md) and the installed version's help/tool schema. Discover MCP tools before calling them; do not invent tool names or assume features on main are released. If REA is unavailable, report that and supply setup instructions; do not silently install software or change global agent configuration. Native providers and commercial analysis tools require their own licenses.

Prefer documentation and authorized observable behavior, then the smallest sufficient static analysis. Runtime execution, device operations, network interception and third-party service interaction need authorization covering those effects; static-analysis authorization does not imply it. Keep target binaries, extracted resources, decompiled output, captures and raw evidence outside the Git tree or under ignored `work/rea/`. Do not upload them or include them in a PR. Local REA processing does not prevent the agent's model provider from receiving tool output: limit output to authorized, non-sensitive evidence.

For Flutter targets, build identification or partial AOT evidence is not recovered Dart source or proof of a complete algorithm. Record the REA version, target digest/version, evidence references, observations, inferences and limitations. Do not imply device verification from static findings.

## Implement from a sanitized specification

Write a short behavioral specification containing inputs, outputs, edge cases and acceptance tests. Exclude copied code, pseudocode, proprietary constants/tables, assets, branding and private endpoint details. Implement from this specification in FRAME's owning layer with original code. Do not describe this single-agent process as a certified clean-room process or a noninfringement guarantee.

If the user instead asks to reuse licensed source/assets, verify explicit reuse and redistribution permission and license compatibility first, preserve required notices, and update [THIRD_PARTY_NOTICES.md](../../../THIRD_PARTY_NOTICES.md). When rights remain unclear, omit that material and explain the unresolved dependency. AI rewriting does not remove source obligations.

Follow the repository's regression, privacy, camera, screenshot and device-verification requirements. Report the changed behavior, relevant provenance, checks actually run and remaining uncertainty. Do not commit, publish, deploy or submit to a store merely because research or implementation was authorized. MIT's standard terms apply; the skill adds no license restriction or guarantee of legal immunity.
