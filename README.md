# 取景 · FRAME

[简体中文](README.md) | [English](README.en.md)

一款用于学习与研究的构图相机应用：点选主体，获得六种经典构图建议，跟随实时引导调整画面。画面分析在本机完成。

![取景：点选主体、构图建议、对齐拍照与拍照指南](docs/images/frame-overview.png)

本项目采用 MIT 许可，开发者可自行修改、分发或上架。为方便发布，项目提供签名配置示例、本地政策页面、发布检查表和软著材料模板，开发者可按需调整并填写自己的资料，见 [分发与上架准备](docs/distribution/README.md)。

## 下载

| 平台 | 下载入口 |
| --- | --- |
| Android | 待补充 APK 下载链接 |
| iOS | 待补充安装或 TestFlight 链接 |

<!-- Replace these placeholders only when a verified build is available. -->
暂无可用下载链接；可按下方步骤自行运行。

## 快速开始

安装 **Flutter 3.47.6**、Git 和 Chrome：

~~~sh
git clone https://github.com/lianjiehao/frameapp.git
cd frameapp
flutter pub get --enforce-lockfile
flutter run -d chrome
~~~

Android 7.0+ 真机运行：`flutter run -d <device-id>`；手机练习模式追加 `--dart-define=DEMO_MODE=true`。iOS 15+ 需要 macOS、Xcode 和自己的开发团队，见 [iOS 配置](docs/ios-setup.zh-CN.md)。帮助与政策页面在本地渲染。

## 开发与贡献

- [应用介绍](docs/app.zh-CN.md)：功能与使用限制。
- [AI 辅助开发](docs/ai-development.zh-CN.md)：Codex、Claude Code、Cursor 共用项目规则；“提交代码”会先预览全部改动并等待确认。
- [架构说明](docs/architecture.zh-CN.md) · [贡献指南](CONTRIBUTING.md)：源码入口、检查命令与 PR 流程。
- [REA 功能研究](docs/rea.zh-CN.md)：使用可选的 `frame-rea` skill 分析自有或已获授权的软件，将经核实的功能需求转为实现。

## 法律与许可

代码采用 [MIT](LICENSE)，依赖、字体与素材遵循[各自许可](THIRD_PARTY_NOTICES.md)。项目的功能演示与研究流程面向学习、研究和实验；这一定位**不限制 MIT 授予的商用、修改或分发权利**。

软件按现状提供，不保证适用性或上架审核通过。使用、逆向分析和分发者应自行核实授权，尊重版权、隐私与肖像权，并承担自身行为对应的责任。免责声明不能排除法律不得排除的责任，详见 [使用与许可边界](docs/legal.zh-CN.md)。安全问题见 [SECURITY.md](SECURITY.md)。
