# AI 辅助开发

[English](ai-development.md) | [简体中文](ai-development.zh-CN.md)

## 统一规则来源

[AGENTS.md](../AGENTS.md) 集中维护架构边界、相机／隐私约束、检查命令和交付要求。共用规则只改这一份，避免不同编辑器各写一套。规则引导助手，测试、人工审查和仓库设置决定能否采用。

| 工具 | 仓库入口 | 使用方式 |
| --- | --- | --- |
| Codex | `AGENTS.md` | 在仓库根目录启动或打开项目；首次修改前，让它概括当前适用的项目规则。 |
| Claude Code | `CLAUDE.md` 导入 `@AGENTS.md` | 在根目录启动，用 `/memory` 查看加载的指令。 |
| Cursor | `.cursor/rules/project.mdc`，设置 `alwaysApply: true` 并引用 `@AGENTS.md` | 打开根目录，在 Settings → Rules 检查项目规则；版本未解析引用时手动将 AGENTS.md 加入上下文。 |

这些文件随仓库提交，无需私人账号配置、全局规则或额外安装 skill。工具入口保持简短；更新规范时修改 AGENTS.md，并同步本指南的中英文版本。

格式依据：[Codex 项目指令](https://developers.openai.com/codex/guides/agents-md/)、[Claude Code 指令与导入](https://code.claude.com/docs/en/memory)、[Cursor 项目规则](https://cursor.com/docs/context/rules)。不同版本界面可能变化，以工具实际加载的指令为准。

## 给出可验证的任务

~~~text
先阅读 AGENTS.md 和 docs/architecture.zh-CN.md。
任务：修复 [复现步骤／Issue 链接]。
预期行为：[用户应看到的结果]。
范围：[相关功能]，保留无关改动。
先检查负责该行为的源码和现有测试，再做局部修复。
添加能在原有错误行为下失败的回归测试。
运行相关检查并审阅 diff。
汇报行为变化、实际测试结果，以及仍需真机验证的内容。
~~~

有效任务应包含失败场景和验收条件。先让 AI 了解现有实现，再决定如何修改。较大改动先确定影响模块与用户可见行为。

## 如何审阅 AI 产出

- 提交者自己阅读 diff，核对新 API 是否存在于锁定依赖版本中，以及各平台行为是否覆盖。
- 保留状态转换、坐标、隐私同意、过期帧处理和保存失败重试等约束，具体见 AGENTS.md。
- 迭代时先跑相关测试，再跑对应完整检查。截图、模型自述或 mock 通过都不能证明真机相机行为。
- 密钥、私人照片和签名凭据不进入提示词及提交；普通开发不执行正式签名或商店提交。
- PR 简述主要 AI 辅助部分、人工审阅和验证方式。所有贡献都遵守相同的 [采用流程](../CONTRIBUTING.md#代码如何被采用)。

## 提交与推送 skill

直接说**“提交代码”**，自动使用 [frame-commit](../.agents/skills/frame-commit/SKILL.md)。默认范围是当前仓库的**本地所有未提交改动**：已暂存、未暂存、新增、删除、重命名及未被忽略的未跟踪文件，也包括先前任务留下的改动。它会运行相关检查、生成 commit 说明，展示完整文件列表、推送仓库／分支及其他将一并推送的提交。**你确认这份预览后，才执行暂存、commit 和 push。** 无需提前选择文件；可以修改预览或取消。

| 工具 | 在项目根目录使用 |
| --- | --- |
| Codex | 直接说“提交代码”，或使用 `$frame-commit` |
| Claude Code | `/frame-commit`，通过仓库内的 [命令入口](../.claude/commands/frame-commit.md) 调用 |
| Cursor | 识别仓库 skill 后使用 `/frame-commit` |
| 任意工具 | 直接说“提交代码”；未加载项目规则时，要求读取 `.agents/skills/frame-commit/SKILL.md` |

例如：**“提交代码”**即准备提交全部本地改动。只有明确说“只提交文档改动”等更小范围时，才覆盖默认范围；不能擅自缩小到本次任务或自动拆分提交。已有会话未出现新 skill 时，重新打开项目／会话，或直接引用该文件。

被忽略的文件继续忽略；发现敏感文件先解决，不能静默漏掉改动后声称全部提交。用户明确缩小范围时保留范围外的改动。在 main 上会提出功能分支方案，并遵守所有者维护范围。不会强推、跳过 hooks，或把 push 失败说成成功。commit 后若推送失败，会保留并报告已有提交，方便重试，不重复生成 commit。

共享 skill 位于 `.agents/skills/`，Claude 命令只转到同一份流程。通用项目约束留在 AGENTS.md，提交步骤留在 skill。发现机制参考：[Codex skills](https://developers.openai.com/codex/skills/)、[Claude commands 与 skills](https://code.claude.com/docs/en/skills)、[Cursor skills](https://cursor.com/docs/context/skills)。

## REA 功能研究

使用 [frame-rea](../.agents/skills/frame-rea/SKILL.md) 研究获授权的目标并补充功能。REA 是可选开发工具，不随 App 运行；安装、调用示例与版权边界见 [REA 指南](rea.zh-CN.md)。
