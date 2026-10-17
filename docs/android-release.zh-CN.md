# Android 独立发布

[English](android-release.md) | [简体中文](android-release.zh-CN.md)

供开发者构建和分发自己的版本；日常贡献只需 `flutter run` 或 `flutter build apk --debug`。

## 配置自己的版本

1. 更换 `android/app/build.gradle.kts` 中的 `applicationId`／`namespace`，同步 `MainActivity.kt` 的包声明与目录；更换名称、图标与 `pubspec.yaml` 版本号。仓库包名仅为开发默认值。
2. 准备自己的商店账号及所需登记、备案和权属材料，按目标市场当前要求核实。
3. 创建并妥善备份自己的签名密钥，将 [key.properties.example](../android/key.properties.example) 复制为 `android/key.properties` 并填写。私钥和密码不提交 Git。
4. 完成 [发布材料](distribution/README.md) 与 [政策配置](../policies/README.md)，再构建。

## 构建与验收

~~~sh
flutter pub get --enforce-lockfile
flutter build appbundle --release
# 目标市场要求 APK 时：
flutter build apk --release
~~~

缺少发布签名配置时，构建会失败，不回退到调试密钥。首次发布后，更新需遵循目标渠道对应用标识和签名连续性的要求。

核对实际产物的标识、版本与签名，按 [发布检查表](release-checklist.zh-CN.md) 完成真机验证，再由独立发布者自行上传。编译成功不代表通过市场审核。
