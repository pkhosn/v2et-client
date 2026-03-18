# V2ET Client (Hiddify-based)

面向 V2Board 的多平台客户端二开项目，主线基于 Hiddify。

当前开发分支：`develop`

## 1. 项目目标

- 支持平台：Windows / macOS / Linux / Android（iOS 作为后续专项）
- 核心能力：登录即自动同步套餐和线路、连接即用
- 技术路线：Hiddify + sing-box + V2ET 适配层

## 2. 代码拉取

```bash
git clone git@github.com:pkhosn/v2et-client.git
cd v2et-client
git checkout develop
```

## 3. 构建环境要求

- Flutter：`3.38.5`（见 `pubspec.yaml`）
- Dart：随 Flutter SDK
- 平台工具链：
  - Windows：Visual Studio Build Tools + Windows Desktop
  - macOS：Xcode + CocoaPods
  - Linux：clang/cmake/ninja + GTK 依赖
  - Android：Android SDK + NDK + Java 17+

先检查环境：

```bash
flutter doctor -v
```

## 4. 打包前统一步骤

### 4.0 生产环境对象存储地址（必改项）

打包前如需切换生产配置源，请先修改：

- `lib/v2et/config/v2et_bootstrap_config.dart`

字段：

- `V2etBootstrapConfig.defaultConfigUrl`

示例：

```dart
static const defaultConfigUrl = 'https://hko-1312628321.cos.ap-guangzhou.myqcloud.com/config.json';
```

说明：

- 客户端默认从该 OSS 地址读取配置 JSON，再解析真实 API。
- 登录页默认不展示该地址输入框（商业模式）；仅在“高级网络设置”中可手动覆盖。

```bash
flutter clean
flutter pub get
```

## 5. 各平台打包命令

### 5.1 Windows

```bash
flutter config --enable-windows-desktop
flutter build windows --release
```

产物目录：

- `build/windows/x64/runner/Release/`

### 5.2 macOS

```bash
flutter config --enable-macos-desktop
flutter build macos --release
```

产物目录：

- `build/macos/Build/Products/Release/`

说明：当前策略为 Mac 不区分架构发布（统一 DMG/PKG 流程后续补齐）。

### 5.3 Linux

```bash
flutter config --enable-linux-desktop
flutter build linux --release
```

产物目录：

- `build/linux/x64/release/bundle/`

### 5.4 Android APK

```bash
flutter build apk --release
```

产物目录：

- `build/app/outputs/flutter-apk/app-release.apk`

### 5.5 Android AAB

```bash
flutter build appbundle --release
```

产物目录：

- `build/app/outputs/bundle/release/app-release.aab`

## 6. 快速测试建议

建议每次打包后验证以下路径：

1. 打开客户端 -> V2ET 登录
2. 登录成功后自动同步套餐与线路
3. Dashboard 一键连接
4. 智能分流 / 全局 / TUN 切换
5. Store / Me 页面数据加载（公告、套餐、订单/工单计数）

## 7. 常见问题

### 7.1 `flutter: command not found`

说明本机未安装 Flutter 或 PATH 未配置。安装 Flutter 后重开终端再执行。

### 7.2 Android 打包失败（SDK/NDK/Java）

优先执行：

```bash
flutter doctor -v
```

按输出补齐 Android Toolchain。

### 7.3 macOS 签名或公证失败

本地测试包可先不公证；正式分发时补 Developer ID、notarization 与 stapler。

## 8. 当前开发进度摘要

- 已完成 V2ET 登录自动同步主链路
- 已完成 Dashboard / Store / Me 三页壳
- 已接入 portal API（公告/套餐/订单工单计数）
- 仍在持续优化 UI 细节与多面板兼容

## 9. 版本备份策略

- 重要功能完成后立即推送 `develop` 作为备份
- 系统重置后按 `docs/v2et/RESET_CHECKLIST.md` 快速恢复
