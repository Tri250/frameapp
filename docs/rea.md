# Research features with REA

[简体中文](rea.zh-CN.md) | [English](rea.md)

[REA](https://github.com/morluto/rea) exposes app behavior, package and binary analysis through MCP and a CLI. This repository's [frame-rea](../.agents/skills/frame-rea/SKILL.md) is an optional development entry point; REA is not an app runtime dependency.

## Setup and use

Check Node.js and provider requirements in the [official setup guide](https://github.com/morluto/rea/blob/main/docs/installation.md), run `npx rea-agents setup`, review configuration changes and restart your assistant. This repository does not automatically install REA or commercial decompilers.

From the repository root, use `$frame-rea` in Codex or `/frame-rea` in Claude Code. Cursor can discover the project skill, or you can explicitly request its file. Example:

~~~text
Use frame-rea. The reference is a local test app I am authorized to examine;
the authorized scope is offline static analysis. Study its exposure controls,
write a behavioral specification without third-party code or assets, then
implement a similar feature in FRAME. Inspect the existing code, add regression
coverage and state the evidence limitations.
~~~

Flow: confirm target and authority → inspect evidence → write a sanitized behavioral specification → implement original code → verify regressions. If REA is unavailable, the assistant reports the missing capability and can continue from public documentation or a specification you supply.

## Rights and data boundaries

REA's MIT license does not authorize analysis of a target. Examine software you own or are appropriately authorized to analyze. Do not bypass DRM, payment, licensing or access controls, or commit decompiled code, third-party assets, keys or private data. Keep raw investigation material outside the repository or under ignored `work/rea/`.

REA analyzes locally, but tool output may enter the AI provider's context; establish the permitted processing scope first. Flutter build identification and partial AOT evidence are not full source recovery. Behavioral specifications and original implementation do not guarantee freedom from infringement liability; see [legal boundaries](legal.md) and [REA's disclaimer](https://github.com/morluto/rea/blob/main/DISCLAIMER.md).
