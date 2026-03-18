# V2ET Branding & Release Prep

This checklist is the **single source of truth** before packaging.

## 1) Brand logo/icon assets

Source logo (SVG):

- `assets/images/logo.svg`

This SVG is used by in-app UI. Packaging icons are platform-specific binary formats and must be prepared before build.

Required packaging icon files:

- Windows icon: `windows/runner/resources/app_icon.ico`
- Linux icon source: `assets/images/source/ic_launcher_border.png`
- macOS/iOS app icons: asset sets in `macos/Runner/Assets.xcassets/AppIcon.appiconset/` and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Recommended conversion flow from SVG:

1. Export 1024x1024 PNG from `assets/images/logo.svg`
2. Generate ICO for Windows from that PNG
3. Replace the files listed above

## 2) Version number (starts at 1.0)

Primary version is defined in:

- `pubspec.yaml` -> `version: 1.0.0+1`

Notes:

- `1.0.0` = marketing version
- `+1` = build number
- Windows MSIX also has its own explicit version in:
  - `windows/packaging/msix/make_config.yaml` -> `msix_version`

## 3) Package/app identifiers and display names

These are **not changeable after shipping binaries** without rebuilding.

### Flutter app package metadata

- `pubspec.yaml` -> `name` (Dart package name, internal)

### Android

- `android/app/build.gradle`
  - `namespace`
  - `applicationId`
- `android/app/src/main/AndroidManifest.xml`
  - `android:label`
- `android/app/src/main/res/xml/shortcuts.xml`
  - `android:targetClass`
  - `android:targetPackage`

### iOS

- `ios/Base.xcconfig`
  - `BASE_BUNDLE_IDENTIFIER`
  - `SERVICE_IDENTIFIER`
- `ios/Runner/Info.plist`
  - `CFBundleDisplayName`
  - URL scheme entries
- `ios/exportOptions.plist`
  - provisioning profile bundle-id map

### macOS

- `macos/Runner/Configs/AppInfo.xcconfig`
  - `PRODUCT_NAME`
  - `PRODUCT_BUNDLE_IDENTIFIER`
- `macos/Runner/Info.plist`
  - URL scheme entries
- `macos/packaging/dmg/make_config.yaml`
  - DMG title/app path

### Windows

- `windows/CMakeLists.txt`
  - project name and binary name
- `windows/runner/main.cpp`
  - app window title/mutex names
- `windows/runner/Runner.rc`
  - file metadata (company/product/internal/original filename)
- `windows/packaging/exe/make_config.yaml`
  - display name/publisher/install dir
- `windows/packaging/msix/make_config.yaml`
  - display name/identity/execution alias/protocol activation

### Web

- `web/manifest.json`
  - `name`, `short_name`, `description`

### Linux

- `linux/packaging/appimage/make_config.yaml`
- `linux/packaging/deb/make_config.yaml`
- `linux/packaging/com.v2et.client.appdata.xml`

## 4) Current V2ET defaults in repo

This repository is currently aligned to brand `V2ET` for:

- app display names
- package identifiers (core locations)
- default version baseline `1.0.0+1`

Before every release, verify all files above again to avoid old brand remnants in installers.

## 5) Login UI placeholder items to replace before production package

Current login screen can use temporary brand text/assets during iteration.

Before production packaging, verify and replace in:

- `lib/v2et/presentation/v2et_login_page.dart`
  - left panel brand title/subtitle/copyright
  - temporary logo image source

## 6) Runtime customer-service integration (no repack)

The client supports dynamic support entry via remote config:

- `crisp.website_id` (or alias keys listed in `CONFIG_STRATEGY.md`)
- `support.url` (direct web客服 URL)
- `support.script_url` (external JS script injection)
- `support.embed_html` (custom HTML injection)

Priority in client:

1. `support.url`
2. `crisp.website_id`
3. `support.embed_html`
4. `support.script_url`

This allows switching客服平台 without rebuilding the app package.
