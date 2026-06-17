import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_dimens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? AppColors.dark : AppColors.light;
    final baseTextStyle = GoogleFonts.notoSansSc();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.bg,
      fontFamily: baseTextStyle.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: palette.bgElevated,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: palette.text,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSansSc(
          color: palette.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: palette.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.bgElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: AppDimens.topRadius24,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.bgElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimens.r20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.glassWhite,
        contentPadding: AppDimens.inputContentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.r16),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.r16),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.r16),
          borderSide: BorderSide(color: palette.border),
        ),
        hintStyle: GoogleFonts.notoSansSc(color: palette.textTertiary),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.notoSansSc(
          color: palette.text,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.notoSansSc(
          color: palette.text,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.notoSansSc(
          color: palette.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.notoSansSc(
          color: palette.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.notoSansSc(
          color: palette.text,
          fontSize: 16,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.notoSansSc(
          color: palette.text,
          fontSize: 14,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.notoSansSc(
          color: palette.textSecondary,
          fontSize: 12,
        ),
        labelMedium: GoogleFonts.notoSansSc(
          color: palette.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconTheme: IconThemeData(color: palette.text),
      dividerColor: palette.borderSubtle,
      cardTheme: CardThemeData(
        color: palette.glassWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.r20),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
}
