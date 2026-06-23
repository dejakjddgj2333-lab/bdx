# 项目规则

## 打包规则

- **每次打包（build），build number 都要 +1。**
  - build number 是本目录 `pubspec.yaml` 中 `version` 字段 `+` 号后的数字。
  - 例如 `version: 1.0.5+22`，下次打包前需改为 `version: 1.0.5+23`。
  - 在执行任何打包命令（如 `flutter build apk` / `flutter build ipa` / `flutter build ios`）之前，先将 build number 加 1。
