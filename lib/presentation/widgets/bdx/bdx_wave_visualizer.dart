import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// 语音通话声波可视化器
///
/// 使用渐变正弦波替代矩形均衡器， active 时振幅更大、颜色更亮。
class BdxWaveVisualizer extends StatelessWidget {
  final Animation<double> animation;
  final bool active;
  final double width;
  final double height;

  const BdxWaveVisualizer({
    super.key,
    required this.animation,
    this.active = false,
    this.width = 260,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _WavePainter(
        animation: animation,
        active: active,
        primaryColor: AppColors.primaryLight,
        secondaryColor: AppColors.success,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Animation<double> animation;
  final bool active;
  final Color primaryColor;
  final Color secondaryColor;

  _WavePainter({
    required this.animation,
    required this.active,
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value * 2 * pi;

    _drawWave(
      canvas,
      size,
      phase: phase,
      frequency: 3.5,
      amplitude: active ? 22 : 6,
      strokeWidth: 4,
      colors: [primaryColor, secondaryColor],
      opacity: 1.0,
    );

    _drawWave(
      canvas,
      size,
      phase: -phase * 1.3 + pi / 3,
      frequency: 5.0,
      amplitude: active ? 14 : 4,
      strokeWidth: 2.5,
      colors: [secondaryColor, primaryColor],
      opacity: active ? 0.5 : 0.25,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double phase,
    required double frequency,
    required double amplitude,
    required double strokeWidth,
    required List<Color> colors,
    required double opacity,
  }) {
    final centerY = size.height / 2;
    final path = Path();

    for (double x = 0; x <= size.width; x += 2) {
      // 两端逐渐收拢的包络，避免硬切
      final envelope = sin((x / size.width) * pi);
      final y = centerY +
          sin((x / size.width) * frequency * pi + phase) *
              amplitude *
              envelope;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: colors.map((c) => c.withValues(alpha: opacity)).toList(),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => oldDelegate != this;
}
