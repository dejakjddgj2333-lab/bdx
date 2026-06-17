import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// 语音通话「连接中」动画
///
/// 中心 Logo + 两圈不断扩散、淡出的光环，营造「正在建立连接」的感知。
class BdxConnectingRing extends StatelessWidget {
  final Animation<double> animation;
  final double size;

  const BdxConnectingRing({
    super.key,
    required this.animation,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(animation: animation),
          ),
          Image.asset(
            'assets/images/logo.png',
            width: size * 0.45,
            height: size * 0.45,
            fit: BoxFit.contain,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Icon(
              Icons.auto_awesome,
              color: AppColors.primaryLight,
              size: size * 0.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Animation<double> animation;

  _RingPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final offset = i / 3;
      final t = (animation.value + offset) % 1.0;
      final radius = maxRadius * 0.35 + maxRadius * 0.55 * t;
      final opacity = (1 - t) * 0.5;
      final strokeWidth = 2 + (1 - t) * 2;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = AppColors.primaryLight.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => oldDelegate != this;
}
