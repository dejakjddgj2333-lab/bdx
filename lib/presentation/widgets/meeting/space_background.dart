import 'package:flutter/material.dart';

/// 会议页面共享的深空背景：径向渐变 + 星点。
///
/// lobby 与 meeting room 复用，保证两个页面视觉连续。
/// [starOpacity] 用于在视频画面为主的 room 中降低星点存在感。
class SpaceBackground extends StatelessWidget {
  final double starOpacity;
  final Alignment gradientCenter;
  final double gradientRadius;

  const SpaceBackground({
    super.key,
    this.starOpacity = 0.6,
    this.gradientCenter = const Alignment(0.9, -0.9),
    this.gradientRadius = 1.4,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: gradientCenter,
                radius: gradientRadius,
                colors: const [Color(0xFF1A153A), Color(0xFF07060F)],
              ),
            ),
          ),
        ),
        Positioned.fill(child: _StarField(opacity: starOpacity)),
      ],
    );
  }
}

class _StarField extends StatelessWidget {
  final double opacity;
  const _StarField({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(opacity: opacity));
  }
}

class _StarPainter extends CustomPainter {
  // 固定星点坐标（比例），避免随机导致每帧抖动
  static const _stars = [
    [0.15, 0.08, 1.4],
    [0.42, 0.05, 1.0],
    [0.62, 0.10, 1.6],
    [0.85, 0.06, 1.1],
    [0.30, 0.16, 0.9],
    [0.92, 0.20, 1.3],
    [0.08, 0.30, 1.0],
    [0.70, 0.55, 1.2],
    [0.20, 0.62, 1.0],
    [0.88, 0.70, 1.4],
    [0.50, 0.80, 1.0],
    [0.12, 0.88, 1.2],
    [0.78, 0.90, 1.0],
  ];

  final double opacity;
  _StarPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    for (final s in _stars) {
      canvas.drawCircle(
        Offset(s[0] * size.width, s[1] * size.height),
        s[2],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
