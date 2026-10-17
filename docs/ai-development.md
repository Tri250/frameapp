# AI-assisted development

[English](ai-development.md) | [简体中文](ai-development.zh-CN.md)

## One source of project rules

[AGENTS.md](../AGENTS.md) holds the architecture boundaries, camera/privacy contracts, test commands and handoff requirements. Keep shared rules there so editors do not drift apart. Rules guide an assistant; tests, code review and repository settings enforce acceptance.

| Tool | Repository entry | How to start |
| --- | --- | --- |
| Codex | `AGENTS.md` | Open this repository root or start Codex there. Ask it to summarize the applicable project rules before its first edit. |
| Claude Code | `CLAUDE.md` importing `@AGENTS.md` | Start in the root. Use `/memory` to inspect loaded instructions. |
| Cursor | `.cursor/rules/project.mdc` with `alwaysApply: true` and `@AGENTS.md` | Open the root folder. Check the project rule in Settings → Rules and include AGENTS.md in context if your version does not resolve the reference. |

These are checked-in project files; no private account, global configuration or optional skill installation is required. Adapters are deliberately short. When changing rules, change AGENTS.md and keep this guide's Chinese/English pair aligned.

Official format references: [Codex project instructions](https://developers.openai.com/codex/guides/agents-md/), [Claude Code memory/imports](https://code.claude.com/docs/en/memory), [Cursor project rules](https://cursor.com/docs/context/rules). Tool interfaces may vary by version; confirm the loaded instructions in the tool you use.

## Give a verifiable task

~~~text
Read AGENTS.md and docs/architecture.md first.
Task: fix [reproduction steps / linked issue].
Expected behavior: [what the user should observe].
Scope: [affected feature]; preserve unrelated changes.
Inspect the owning code and existing tests, then implement a focused fix.
Add a regression that fails for the original behavior.
Run the relevant checks and review the diff.
Report changed behavior, actual test results, and anything requiring a device.
~~~

A useful task specifies a failing case and acceptance criteria. Let the agent inspect the code before prescribing a rewrite. For a large change, agree on the affected modules and observable behavior before implementation.

## Review AI output

- Read the diff yourself. Confirm that new APIs exist in the locked dependency versions and that platform behavior is covered.
- Keep state transitions, coordinates, consent, stale-frame handling and failed-save retry intact. Those contracts are listed in AGENTS.md.
- Prefer targeted tests during iteration, then the relevant full checks. A screenshot, model assertion or passing mock does not prove native camera behavior.
- Keep secrets, private photos, signing data and credentials out of prompts and commits. Keep release signing and store submissions outside ordinary development.
- In the PR, describe significant AI assistance, your review and verification. The same [acceptance process](../CONTRIBUTING.en.md#how-changes-are-accepted) applies to all contributions.

## Commit and push skill

Say **“提交代码”** or **“commit code”** to automatically use [frame-commit](../.agents/skills/frame-commit/SKILL.md). Its default scope is **all local uncommitted changes** in this repository: staged, unstaged, added, deleted, renamed and non-ignored untracked files, including earlier tasks' work. It runs relevant checks, drafts the message and shows the complete file list, push repository/branch and other outgoing commits. **Only after you confirm that preview does it stage, commit and push.** No preliminary file-selection question is needed; you can revise the preview or cancel.

| Tool | Invoke from the project root |
| --- | --- |
| Codex | Say “提交代码” or use `$frame-commit` |
| Claude Code | `/frame-commit`, via the checked-in [command](../.claude/commands/frame-commit.md) |
| Cursor | `/frame-commit` after the repository skill is discovered |
| Any tool | Say “提交代码”; if the project rules are not loaded, ask it to read `.agents/skills/frame-commit/SKILL.md` |

Example: **“提交代码”** prepares the entire local change set. To override that default explicitly, say “Commit only the documentation changes.” Do not limit an unqualified request to the latest task or split the commit automatically. If a new skill is not listed in an existing session, reopen the project/session or use the explicit file path.

Ignored files stay ignored; sensitive-file blockers must be resolved without silently omitting changes and claiming a complete submission. An explicitly narrower scope preserves excluded work. The workflow proposes a feature branch when on main and respects owner-only paths. It does not force-push, skip hooks or claim a failed push succeeded. If pushing fails after a commit, it retains and reports that commit so you can retry without duplicating it.

The shared skill lives under `.agents/skills/`; the Claude command delegates to it. Keep project constraints in AGENTS.md and the commit workflow in the skill. Discovery formats: [Codex skills](https://developers.openai.com/codex/skills/), [Claude commands and skills](https://code.claude.com/docs/en/skills), [Cursor skills](https://cursor.com/docs/context/skills).

## REA feature research

Use [frame-rea](../.agents/skills/frame-rea/SKILL.md) to study authorized targets and extend features. REA is optional development tooling, not an app runtime dependency. See the [REA guide](rea.md) for setup, invocation and rights boundaries.
