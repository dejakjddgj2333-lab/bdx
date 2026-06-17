import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class BdxLoading extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const BdxLoading({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.5,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary,
        ),
      ),
    );
  }
}

/// 三个点的打字/等待动画，替代传统 loading
class BdxTypingDots extends StatefulWidget {
  final double dotSize;
  final Color? color;

  const BdxTypingDots({
    super.key,
    this.dotSize = 8,
    this.color,
  });

  @override
  State<BdxTypingDots> createState() => _BdxTypingDotsState();
}

class _BdxTypingDotsState extends State<BdxTypingDots>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.25;
            final value = ((_controller.value + delay) % 1.0);
            final scale = 0.5 + (value < 0.5 ? value * 2 : (1 - value) * 2) * 0.6;
            return Container(
              width: widget.dotSize * scale,
              height: widget.dotSize * scale,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.color ?? AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
