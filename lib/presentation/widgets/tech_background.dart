import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 科技感背景装饰（高级版）
///
/// - 缓慢漂移的渐变光斑，营造「呼吸」般的空间感
/// - 径向暗角让视觉焦点汇聚到内容
/// - 低对比度网格线保留科技细节
/// - 所有动画仅驱动背景层，不影响 child
class TechBackground extends StatefulWidget {
  final Widget child;
  final bool showGrid;

  const TechBackground({
    super.key,
    required this.child,
    this.showGrid = true,
  });

  @override
  State<TechBackground> createState() => _TechBackgroundState();
}

class _TechBackgroundState extends State<TechBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        // 动态光斑
        _AnimatedBlob(
          controller: _controller,
          color: AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.12),
          size: 360,
          begin: const Alignment(-1.2, -0.6),
          end: const Alignment(0.8, 0.2),
          scaleBegin: 0.9,
          scaleEnd: 1.25,
        ),
        _AnimatedBlob(
          controller: _controller,
          color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.10),
          size: 420,
          begin: const Alignment(1.2, 0.4),
          end: const Alignment(-0.6, -0.8),
          scaleBegin: 1.0,
          scaleEnd: 1.35,
        ),
        _AnimatedBlob(
          controller: _controller,
          color: AppColors.pink.withValues(alpha: isDark ? 0.12 : 0.06),
          size: 300,
          begin: const Alignment(-0.4, 1.0),
          end: const Alignment(0.6, -0.4),
          scaleBegin: 0.85,
          scaleEnd: 1.15,
        ),
        // 暗角
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [
                Colors.transparent,
                colors.bg.withValues(alpha: isDark ? 0.55 : 0.28),
              ],
              stops: const [0.45, 1.0],
            ),
          ),
        ),
        if (widget.showGrid)
          Opacity(
            opacity: isDark ? 0.03 : 0.04,
            child: const CustomPaint(
              painter: _GridPainter(),
              size: Size.infinite,
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;
  final Alignment begin;
  final Alignment end;
  final double scaleBegin;
  final double scaleEnd;

  const _AnimatedBlob({
    required this.controller,
    required this.color,
    required this.size,
    required this.begin,
    required this.end,
    this.scaleBegin = 0.9,
    this.scaleEnd = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = AlignmentTween(begin: begin, end: end)
        .chain(CurveTween(curve: Curves.easeInOutSine))
        .animate(controller);
    final scale = Tween<double>(begin: scaleBegin, end: scaleEnd)
        .chain(CurveTween(curve: Curves.easeInOutSine))
        .animate(controller);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          alignment: alignment.value,
          child: Transform.scale(
            scale: scale.value,
            child: child,
          ),
        );
      },
      child: _glow(color, size),
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
          stops: const [0.0, 0.72],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
