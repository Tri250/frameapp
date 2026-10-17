# 用 REA 研究功能

[简体中文](rea.zh-CN.md) | [English](rea.md)

[REA](https://github.com/morluto/rea) 通过 MCP／命令行帮助代理检查应用行为、程序包和二进制证据。本项目提供 [frame-rea](../.agents/skills/frame-rea/SKILL.md) 作为可选开发入口，不将 REA 加入 App 运行依赖。

## 接入与调用

按 [REA 官方安装指南](https://github.com/morluto/rea/blob/main/docs/installation.md) 核对 Node.js 和分析工具要求，运行 `npx rea-agents setup`，审阅配置变更后重启助手。仓库不会自动安装 REA 或商业反编译器。

在仓库根目录向 Codex 输入 `$frame-rea`；Claude Code 可用 `/frame-rea`；Cursor 可发现项目 skill，也可明确要求读取其文件。示例：

~~~text
使用 frame-rea。参考对象是我有权分析的本地测试应用，授权范围为离线静态分析。
研究它的曝光调节输入与输出，形成不含第三方代码或素材的行为说明，
再为 FRAME 实现同类功能。先核对现有实现，补充回归测试，并说明证据局限。
~~~

流程：确认目标与授权 → 检查证据 → 编写脱敏行为规格 → 原创实现 → 回归验证。未安装 REA 时，助手应说明缺少的能力，仍可依据公开文档或你提供的规格继续开发。

## 版权与数据边界

REA 的 MIT 许可不等于目标软件授权。只分析自有或已获相应授权的软件，不绕过 DRM、付费、授权或访问控制，不将反编译代码、第三方素材、密钥或私人数据提交到仓库。原始分析材料放在仓库外或被忽略的 `work/rea/`。

REA 在本地分析，但工具结果可能进入 AI 服务商上下文；先确认允许的处理范围。Flutter 构建识别和部分 AOT 信息不等于完整源码恢复。功能规格与原创实现也不能保证完全排除侵权责任，详见 [使用与许可边界](legal.zh-CN.md) 及 [REA 免责声明](https://github.com/morluto/rea/blob/main/DISCLAIMER.md)。
