import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 科技感背景装饰
///
/// 在页面底层绘制渐变光晕与网格线，营造沉浸感。
/// 已适配浅色/深色主题。
///
/// 性能说明：
/// - 光晕是几个静态 Container，仅构建一次
/// - 网格使用 CustomPaint + shouldRepaint=false，Flutter 不会重绘
/// - 整体开销很低，可放心作为全局背景
class TechBackground extends StatelessWidget {
  final Widget child;
  final bool showGrid;

  const TechBackground({
    super.key,
    required this.child,
    this.showGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 基础渐变背景
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.bg,
                isDark ? const Color(0xFF050818) : const Color(0xFFFFFFFF),
                colors.bg,
              ],
            ),
          ),
        ),
        // 顶部紫色光晕
        Positioned(
          top: -140,
          left: -100,
          child: _glow(AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10), 320),
        ),
        // 底部青色光晕
        Positioned(
          bottom: -180,
          right: -120,
          child: _glow(AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08), 360),
        ),
        if (showGrid)
          Opacity(
            opacity: isDark ? 0.03 : 0.04,
            child: CustomPaint(
              painter: _GridPainter(isDark: isDark),
              size: Size.infinite,
            ),
          ),
        child,
      ],
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isDark;

  const _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..strokeWidth = 0.5;

    const step = 56.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.isDark != isDark;
}
