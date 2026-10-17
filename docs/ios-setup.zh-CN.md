# iOS 开发

[English](ios-setup.md) | [简体中文](ios-setup.zh-CN.md)

需要 macOS、完整 Xcode 和 Flutter 3.47.6。工程最低 iOS 15，使用 Swift Package Manager。CI 选择 Xcode 26.3；本机使用与 Mac 和目标设备兼容的 Xcode，再通过 `flutter doctor -v` 检查。

## 编译与运行

1. 完成 Xcode 首次启动和平台组件安装；必要时将其选为当前开发工具目录。
2. 在仓库根目录执行：

~~~sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter devices
open ios/Runner.xcworkspace
~~~

3. 在 Runner → Signing & Capabilities 设置自己的开发团队，必要时更换为唯一 bundle identifier。不要使用维护者团队，也不要提交本机签名变化。
4. 连接并信任 iPhone，按系统要求启用开发者模式，再执行 `flutter run -d <device-id>`。信任与签名使用自己的账号完成。
5. 无签名编译检查可用 `flutter build ios --release --no-codesign`，该结果不能直接安装或上架。

## 权限插件

保留 `ios/Runner/Info.plist` 中已有的相机、仅添加照片和运动用途说明。通过 Flutter 编译时，权限插件读取该文件。直接从 Xcode 启动而相机授权异常时，将构建环境中的 `PERMISSION_HANDLER_INFO_PLIST` 指向当前仓库 `ios/Runner/Info.plist` 的绝对路径，重新解析 Swift 包。不要用添加麦克风或相册读取权限来绕过问题。

## 真机检查

验证首次同意、拒绝与主动重试；实时预览和前后摄方向；主体移动与跟丢；快门和相册保存；保存失败重试；后台恢复；政策页返回；撤回同意。在 PR 记录设备、iOS 版本、提交和实际结果。模拟器或无签名编译成功不代表相机或 App Store 验收通过。

发布者使用自己的团队、Bundle ID、签名与 App Store Connect 账号，完成 [发布材料](distribution/README.md) 和 [发布检查表](release-checklist.zh-CN.md)。
