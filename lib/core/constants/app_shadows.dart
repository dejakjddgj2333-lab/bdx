import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 统一的阴影与发光 Token
///
/// 科技风 App 主要靠「发光」而不是厚重投影。这里把发光拆成
/// 主色光晕 [glowPrimary]、成功色光晕 [glowSuccess]、卡片微投影 [card]
/// 三种常用语义。
class AppShadows {
  AppShadows._();

  /// 主按钮 / 重点元素的发光
  static List<BoxShadow> glowPrimary({double opacity = 0.35}) => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: opacity),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ];

  /// 强调按钮（粉色）发光
  static List<BoxShadow> glowAccent({double opacity = 0.35}) => [
        BoxShadow(
          color: AppColors.pink.withValues(alpha: opacity),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ];

  /// 成功/青色元素发光
  static List<BoxShadow> glowSuccess({double opacity = 0.3}) => [
        BoxShadow(
          color: AppColors.success.withValues(alpha: opacity),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ];

  /// 玻璃卡片微投影（浅色模式下更有存在感）
  static List<BoxShadow> card(BuildContext context) => [
        BoxShadow(
          color: AppColors.of(context).text.withValues(alpha: 0.04),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ];

  /// 头像 / 图标的光晕
  static List<BoxShadow> avatarGlow(Color color, {double opacity = 0.4}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 30,
          spreadRadius: 4,
        ),
      ];

  /// 底部悬浮操作面板投影
  static List<BoxShadow> bottomSheet(BuildContext context) => [
        BoxShadow(
          color: AppColors.of(context).text.withValues(alpha: 0.08),
          blurRadius: 30,
          spreadRadius: 0,
          offset: const Offset(0, -4),
        ),
      ];
}
