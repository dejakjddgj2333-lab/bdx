import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// 品牌空状态插画
///
/// Logo 居中，三颗小星沿不同轨道缓慢公转，整体带呼吸缩放，
/// 替代静态图标，让空状态更有生命力。
class BdxEmptyIllustration extends StatefulWidget {
  final double size;

  const BdxEmptyIllustration({
    super.key,
    this.size = 160,
  });

  @override
  State<BdxEmptyIllustration> createState() => _BdxEmptyIllustrationState();
}

class _BdxEmptyIllustrationState extends State<BdxEmptyIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = widget.size * 0.38;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final breathe = 0.95 + (_controller.value < 0.5
                  ? _controller.value * 2
                  : (1 - _controller.value) * 2) *
              0.08;
          return Transform.scale(
            scale: breathe,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景光晕
            Container(
              width: widget.size * 0.75,
              height: widget.size * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // 轨道 1
            _Orbit(
              controller: _controller,
              radius: widget.size * 0.38,
              starSize: 10,
              color: AppColors.primaryLight,
              turns: 1.0,
              phase: 0.0,
            ),
            // 轨道 2
            _Orbit(
              controller: _controller,
              radius: widget.size * 0.46,
              starSize: 8,
              color: AppColors.success,
              turns: -1.5,
              phase: 0.33,
            ),
            // 轨道 3
            _Orbit(
              controller: _controller,
              radius: widget.size * 0.30,
              starSize: 7,
              color: AppColors.pink,
              turns: 2.2,
              phase: 0.66,
            ),
            // 中心 Logo
            Image.asset(
              'assets/images/logo.png',
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Icon(
                Icons.auto_awesome,
                color: AppColors.primaryLight,
                size: logoSize * 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orbit extends StatelessWidget {
  final AnimationController controller;
  final double radius;
  final double starSize;
  final Color color;
  final double turns;
  final double phase;

  const _Orbit({
    required this.controller,
    required this.radius,
    required this.starSize,
    required this.color,
    required this.turns,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(begin: phase, end: phase + turns)
        .animate(
          CurvedAnimation(
            parent: controller,
            curve: const Interval(0.0, 1.0, curve: Curves.linear),
          ),
        );

    return RotationTransition(
      turns: animation,
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: starSize,
            height: starSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: starSize,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
