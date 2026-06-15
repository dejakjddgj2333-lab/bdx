import 'package:flutter/material.dart';

/// B18.tech 深色科技风配色
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF010510);
  static const Color bgElevated = Color(0xFF0A0C1A);
  static const Color bgCard = Color(0x0BFFFFFF); // rgba(255,255,255,0.045)
  static const Color bgOverlay = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  static const Color primary = Color(0xFF622CD5);
  static const Color primaryDark = Color(0xFF3F2082);
  static const Color primaryLight = Color(0xFF8B51EA);
  static const Color primaryGlow = Color(0xFF9D6AF0);

  static const Color surface = Color(0xFF12142A);
  static const Color surfaceHigh = Color(0xFF1A1D35);

  static const Color accent = Color(0xFFFFD700);
  static const Color pink = Color(0xFFFE53BA);
  static const Color success = Color(0xFF00CEC9);

  static const Color text = Colors.white;
  static const Color textSecondary = Color(0xA6FFFFFF); // 0.65
  static const Color textTertiary = Color(0x66FFFFFF); // 0.4

  static const Color border = Color(0x59622CD5); // 0.35
  static const Color borderSubtle = Color(0x14FFFFFF); // 0.08

  static const Color glassWhite = Color(0x0BFFFFFF);
  static const Color buttonOverlay = Color(0x3D622CD5);

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
}
