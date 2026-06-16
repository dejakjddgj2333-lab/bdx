import 'package:flutter/material.dart';

/// 应用主题模式
enum AppThemeMode {
  /// 浅色模式
  light,

  /// 深色模式
  dark,

  /// 跟随系统
  system,
}

extension AppThemeModeX on AppThemeMode {
  /// 显示名称
  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  /// 选项图标
  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.wb_sunny_outlined;
      case AppThemeMode.dark:
        return Icons.nights_stay_outlined;
      case AppThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  /// 转换为 Flutter ThemeMode
  ThemeMode get toThemeMode {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  static AppThemeMode fromString(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
        return AppThemeMode.system;
      default:
        return AppThemeMode.dark;
    }
  }
}
