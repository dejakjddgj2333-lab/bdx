import 'package:flutter/material.dart';

/// 应用主题调色板
///
/// 通过 [AppColors.of(context)] 获取当前亮度对应的调色板，
/// 品牌色则保持 [AppColors.primary] 等静态常量不变。
class AppColorsPalette {
  final Color bg;
  final Color bgElevated;
  final Color bgCard;
  final Color bgOverlay;

  final Color surface;
  final Color surfaceHigh;

  final Color text;
  final Color textSecondary;
  final Color textTertiary;

  final Color border;
  final Color borderSubtle;

  final Color glassWhite;
  final Color buttonOverlay;

  // 会议页面专用玻璃色调（深色主题下使用）
  final Color meetingControlBarBg;
  final Color meetingCardBg;
  final Color meetingGlassBg;

  const AppColorsPalette({
    required this.bg,
    required this.bgElevated,
    required this.bgCard,
    required this.bgOverlay,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderSubtle,
    required this.glassWhite,
    required this.buttonOverlay,
    required this.meetingControlBarBg,
    required this.meetingCardBg,
    required this.meetingGlassBg,
  });
}

/// B18.tech 配色系统
///
/// 品牌色为全局静态常量；主题相关颜色请使用 [AppColors.of(context)] 获取。
class AppColors {
  AppColors._();

  // ===== 品牌色（不随主题变化） =====
  static const Color primary = Color(0xFF622CD5);
  static const Color primaryDark = Color(0xFF3F2082);
  static const Color primaryLight = Color(0xFF8B51EA);
  static const Color primaryGlow = Color(0xFF9D6AF0);

  static const Color accent = Color(0xFFFFD700);
  static const Color pink = Color(0xFFFE53BA);
  static const Color success = Color(0xFF00CEC9);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary, primaryDark],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B51EA), Color(0xFF00CEC9)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x12FFFFFF), Color(0x06FFFFFF)],
  );

  static const LinearGradient textGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, Color(0xFFA9A9A9)],
  );

  // ===== 主题调色板 =====
  static const AppColorsPalette dark = AppColorsPalette(
    bg: Color(0xFF010510),
    bgElevated: Color(0xFF0A0C1A),
    bgCard: Color(0x0BFFFFFF), // rgba(255,255,255,0.045)
    bgOverlay: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    surface: Color(0xFF12142A),
    surfaceHigh: Color(0xFF1A1D35),
    text: Colors.white,
    textSecondary: Color(0xA6FFFFFF), // 0.65
    textTertiary: Color(0x66FFFFFF), // 0.4
    border: Color(0x59622CD5), // 0.35
    borderSubtle: Color(0x14FFFFFF), // 0.08
    glassWhite: Color(0x0BFFFFFF),
    buttonOverlay: Color(0x3D622CD5),
    meetingControlBarBg: Color(0xFF0F0D1A),
    meetingCardBg: Color(0xFF1C1730),
    meetingGlassBg: Color(0xFF1A1530),
  );

  static const AppColorsPalette light = AppColorsPalette(
    bg: Color(0xFFF5F5F7),
    bgElevated: Color(0xFFFFFFFF),
    bgCard: Color(0x0A000000), // rgba(0,0,0,0.04)
    bgOverlay: Color(0x14000000), // rgba(0,0,0,0.08)
    surface: Color(0xFFE5E5EA),
    surfaceHigh: Color(0xFFD1D1D6),
    text: Color(0xFF000000),
    textSecondary: Color(0xA6000000), // 0.65
    textTertiary: Color(0x66000000), // 0.4
    border: Color(0x59622CD5), // 保持品牌紫色调
    borderSubtle: Color(0x14000000), // 0.08
    glassWhite: Color(0x0A000000),
    buttonOverlay: Color(0x3D622CD5),
    meetingControlBarBg: Color(0xFF0F0D1A),
    meetingCardBg: Color(0xFF1C1730),
    meetingGlassBg: Color(0xFF1A1530),
  );

  /// 获取当前主题对应的调色板
  static AppColorsPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
