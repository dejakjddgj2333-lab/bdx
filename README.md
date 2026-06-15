# 北斗星AI Flutter 客户端

`beidouxing_app_flutter` 是原 `beidouxing-app`（UniApp）的 Flutter 重构版本，功能保持不变，后端接口 100% 兼容。

## 环境要求

- Flutter 3.22+ / 3.44+（已在 3.44.2 验证）
- Dart 3.12+
- Android Studio + Android SDK（compileSdk 36）
- Xcode（iOS 打包需要 macOS）

## 项目结构

```
lib/
├── main.dart              # 入口
├── app.dart               # MaterialApp + 路由 + 主题
├── injection.dart         # get_it 依赖注入
├── core/                  # 常量、主题、工具、异常
├── data/                  # 模型、远程/本地数据源、仓库实现
├── domain/                # 实体、仓库接口
├── presentation/          # Bloc、页面、组件
└── services/              # WebSocket、录音、播放服务
```

## 快速开始

```bash
cd beidouxing_app_flutter
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## Web 支持

本项目已添加 Web 平台支持，可通过以下命令运行或构建：

```bash
# 开发模式运行
flutter run -d chrome --web-port=8081

# Release 构建
flutter build web --release
```

### Web 端限制与注意事项

- **语音通话**：Web 端暂不支持实时 PCM 录音，进入语音通话页面会提示不支持
- **图片上传**：支持，浏览器会弹出文件选择器
- **本地文件存储**：不支持，token 通过 `flutter_secure_storage` 的 Web 实现存于浏览器本地存储
- **CORS**：Web 端请求后端接口需要后端配置跨域，确保以下响应头正确返回：
  ```http
  Access-Control-Allow-Origin: *
  Access-Control-Allow-Headers: Content-Type, Authorization
  Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
  ```
- **record 插件兼容**：由于 `record` 官方 `record_web` 与 `record_platform_interface` 2.1.0 存在版本冲突，项目使用本地 `record_web_stub/` 作为 Web 端占位实现，不影响 Android/iOS 端真实录音功能

## 打包

```bash
# Android debug
flutter build apk --debug

# Android release
flutter build apk --release

# iOS
flutter build ios --release

# Web release
flutter build web --release
```

## 核心依赖

- flutter_bloc：状态管理
- go_router：路由
- dio：HTTP 请求
- hive / flutter_secure_storage：本地存储
- flutter_markdown：Markdown 渲染
- web_socket_channel：WebSocket
- record / audioplayers：语音通话录音与播放
- image_picker / flutter_image_compress：图片选择与压缩

## 后端接口

完全复用原后端接口，详见 `lib/core/constants/api_constants.dart`。

## 注意事项

- 首次 Android 构建会自动下载 NDK/CMake，耗时较长
- record 插件版本存在平台接口兼容问题，已在 `pubspec.yaml` 通过 `dependency_overrides` 解决
- 原 UniApp 项目 `beidouxing-app` 已保留，未做任何修改
