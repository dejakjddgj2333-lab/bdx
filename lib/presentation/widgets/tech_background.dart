import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 深色科技风背景装饰
///
/// 在页面底层绘制渐变光晕与网格线，营造 B18.tech 风格的沉浸感。
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // 基础渐变背景
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.bg,
                Color(0xFF050818),
                AppColors.bg,
              ],
            ),
          ),
        ),
        // 顶部紫色光晕
        Positioned(
          top: -140,
          left: -100,
          child: _glow(AppColors.primary.withOpacity(0.18), 320),
        ),
        // 底部青色光晕
        Positioned(
          bottom: -180,
          right: -120,
          child: _glow(AppColors.success.withOpacity(0.12), 360),
        ),
        if (showGrid)
          Opacity(
            opacity: 0.03,
            child: CustomPaint(
              painter: _GridPainter(),
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
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
  bool shouldRepaint(covariant CustomPainter) => false;
}
