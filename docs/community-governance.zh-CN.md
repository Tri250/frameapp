# 维护者协作流程

[English](community-governance.md) | [简体中文](community-governance.zh-CN.md)

## 合并与发布

使用短期分支，提交聚焦的 PR 到 `main`；外部贡献者使用 Fork。审查产品方向、实现、回归证据与平台影响，解决讨论后 Squash 合并，保留作者与共同作者署名。合并不代表立即上架。

独立发布者使用自己的身份与凭据。自行发布时选定候选 SHA，完成 Android／iOS 真机检查，递增 `pubspec.yaml` 版本及构建号，验收后创建不可移动的 `vX.Y.Z` 标签，从同一提交构建并签名。记录 SHA、构建号、文件哈希和市场状态，使用 [发布检查表](release-checklist.zh-CN.md)。签名和商店凭据不进入 Git 或普通 PR 工作流。

## 启用仓库强制规则

提交模板不等于 GitHub 规则已生效。开放协作或授予 write 权限前，应重新核对当前 Settings 和 Actions 结果。

1. 推送并验证 [.github/workflows](../.github/workflows)，包括固定版本的 Flutter／Xcode 环境。
2. 依次导入 [.github/rulesets/owner-branches.json](../.github/rulesets/owner-branches.json) 和 [.github/rulesets/main.json](../.github/rulesets/main.json)，在仓库可见性／套餐允许时启用两份规则。
3. 核对必需状态：`Code quality`、`Android build`、`iOS build`、`Contributor page ownership`；保留禁止删除／强推、解决讨论和审查要求。
4. 验证普通外部 PR、修改保护路径的外部 PR、所有者分支 PR，以及其他 write 用户无法推送 `owner-contributors`。

main 模板不设 bypass，要求作者以外的 Code Owner 批准。启用前必须为所有者自己的 PR 配备合格的第二名审查者，包括显式路径规则；单人不能批准自己的 PR。CODEOWNERS 本身不能强制拦截合并。当前仓库未配置 Merge Queue。

## 所有者维护内容

贡献记录、分数、页面及共享发布工具只由 `@lianjiehao` 提交。准确路径与用户 ID 见 [.github/contributors-ownership.json](../.github/contributors-ownership.json)，包括整个 `tools/` 和 `.github/`。其他人通过 Issue 申请更正，必要时请求私密渠道。

身份检查核对 PR 作者、来源仓库、改动路径及所有者 `owner-contributors` 分支的实际保护状态。批准、提交邮箱、可编辑署名字段和重跑 CI 的身份都不能绕过检查；改名与删除也受检查。所有者须在主仓库的该分支提交受保护改动，不应为通过 PR 而降低规则。

`pull_request_target` 身份工作流只读取 PR 元数据，执行可信主分支代码，不得执行 PR 代码。普通 CI 只读且不持有签名密钥。Dependabot 对 `.github/` 的更新也需由所有者按该流程另行提交。

## 贡献认可

按已采纳成果及公开 Issue／PR 证据认可，不按行数、提交数、Star 或评论数。所有者确认价值后录入 `policies/community.json`。

| 分值 | 已采纳成果 |
| --- | --- |
| 1 | 小修正、文案或文档完善 |
| 3 | 可复现修复、有效测试／真机验证、小型体验改进 |
| 5 | 验收明确的功能改进、重要稳定性／性能修复 |
| 8 | 实现前先讨论并拆解、完成后验收的重大改进 |

同一成果只计一次；共同完成按约定分摊，总和为 1；撤回成果标记 `reverted` 并移出有效分。草稿、未合入 PR 和自动依赖更新不自动计入个人贡献。页面展示累计分和近 90 天分，同分并列。认可不代表工资、股权或承诺奖励。

公开展示须本人同意，仅展示公开 GitHub 用户名或自选昵称。不参与展示也保留正常提交署名。发布前核实同意与共同作者；更正、分值异议和退出展示通过 Issue 或另行约定的私密渠道处理。

## 政策与贡献者页面

共享政策正文与贡献者记录由所有者维护；`tools/verify_contributions.py` 核对公开成果证据。修改后生成应用内页面，并与源文件一起审阅，见 [本地政策页面](../policies/README.md)。
