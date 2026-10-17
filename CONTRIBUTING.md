# 参与 FRAME

[简体中文](CONTRIBUTING.md) | [English](CONTRIBUTING.en.md)

欢迎问题反馈、修复、测试、真机验证、设计和文档翻译，中文与英文均可。较大功能或架构调整先开 Issue，小而明确的修复可以直接提交 PR。

## 提交 PR

1. Fork 仓库，从最新 `main` 建立分支，例如 `fix/save-retry` 或 `feat/guide-copy`。
2. 一个 PR 解决一个问题。先读 [架构说明](docs/architecture.zh-CN.md) 和 [AGENTS.md](AGENTS.md)，沿用周边实现方式。
3. 行为变化补充回归验证。界面变化附截图；相机、权限、方向、保存或生命周期变化附真机结果，明确未验证的平台。
4. 执行 [提交前检查](#提交前检查)。按 [PR 模板](.github/pull_request_template.md) 说明问题、修改后的行为、检查和已知限制，有 Issue 时关联链接。
5. 根据审查意见修改并重跑相关检查。不提交签名文件、凭据、私人照片、构建产物或无关重构。

首次贡献可从文档、可复现问题、小范围回归修复和真机测试入手。如有 `good first issue` 标签可优先查看；没有合适任务时，先在 Issue 说明范围。

## 代码如何被采用

**PR → 自动检查 → 维护者审查 → 修改完善 → Squash 合入 `main` → 发布验收。**

CI 检查格式、静态分析、Flutter／Python 测试、文档链接、生成页面、最终 APK 权限和 Android／iOS 编译。仓库设置为必需的检查必须通过，但检查通过不代表批准。维护者会核对产品方向、正确性、范围、可维护性及证据，解决审查讨论，并在 PR 说明修改要求或不采用的原因。不承诺固定合并或发布时间。

相机与权限变化在分发前需要真机证据。开发者可依 MIT 自行发布，使用自己的账号、签名与运营资料，见 [独立发布](docs/distribution/README.md)。合并 PR 不授予代作者操作账号或发布的权限。GitHub 强制规则须在服务端启用，见 [维护者协作说明](docs/community-governance.zh-CN.md)。

## 提交前检查

使用 Flutter 3.47.6，在仓库根目录执行：

~~~sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
python3 -m unittest discover -s tools/tests
python3 tools/check_docs.py
~~~

政策源文件变化后运行 `python3 tools/build_policy_pages.py`，提交同步生成的副本。CI 另做 Android 调试包及 iOS 无签名编译，见 [工作流](.github/workflows/ci.yml)。

## AI 辅助贡献

Codex、Claude Code 和 Cursor 共用 [项目规则](AGENTS.md)，接入方式和任务示例见 [AI 开发指南](docs/ai-development.zh-CN.md)。

提交者对每一行代码负责：自己看 diff，理解行为，按实际安装版本核对 API／依赖，汇报真正执行过的检查。不要提交虚构的测试、截图、性能或真机结果。PR 简述主要 AI 辅助部分及人工核查方式即可，无需上传聊天记录。不要向助手发送密钥或私人数据。

## 所有者维护范围

维护规则将 `.github/`、`tools/`、贡献者数据／页面、政策配置及部分共享生成文件限定为 `@lianjiehao` 维护。准确清单见 [.github/contributors-ownership.json](.github/contributors-ownership.json)。其他作者的 PR 不会因为获得批准而豁免身份检查。

涉及这些路径时，请开 Issue 提出改进，由所有者通过 `owner-contributors` 分支流程提交。政策正文也由所有者维护的工具生成，不要直接改 HTML／Dart 副本。普通应用代码和这些开发文档仍可正常贡献。

## 署名与许可

贡献适用项目 [MIT 许可证](LICENSE)；提交者须拥有所提交代码和素材的贡献权利。依赖和字体保留各自许可，见 [第三方与素材说明](THIRD_PARTY_NOTICES.md)。

PR 保留作者身份。多人共同完成时，填写 `Co-authored-by: 姓名 <与 GitHub 关联的邮箱>`，让 squash 提交保留各位实际共同作者。贡献者页面展示为自愿，须本人同意，只列公开 GitHub 用户名或自选昵称。合入代码和其他已采纳成果按 [协作说明](docs/community-governance.zh-CN.md) 认可，不按代码行数或拆分提交计分。

更正记录或退出贡献者页面，可提交 Issue；需要私下处理时只公开请求私密渠道，不附个人资料。安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。
