import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 全局动画效果封装
///
/// 所有微交互、列表进入、页面进入都走这里，避免每个页面写重复动画。
class BdxAnimations {
  BdxAnimations._();

  /// 列表项 / 卡片进入：淡入 + 轻微上滑
  static Widget fadeSlideIn(
    Widget child, {
    int delayMs = 0,
    int durationMs = 400,
    double beginY = 0.12,
  }) {
    return child
        .animate()
        .fadeIn(duration: durationMs.ms, delay: delayMs.ms)
        .slideY(begin: beginY, end: 0, duration: durationMs.ms, delay: delayMs.ms);
  }

  /// 页面整体进入：淡入 + 轻微下滑归位
  static Widget pageEnter(Widget child) {
    return child
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0, duration: 300.ms);
  }

  /// 脉冲呼吸效果（用于通话状态文字、聆听中等）
  static Widget breathe(
    Widget child, {
    double minOpacity = 0.5,
    double maxOpacity = 1.0,
    int durationMs = 2000,
  }) {
    return _BreathingWidget(
      minOpacity: minOpacity,
      maxOpacity: maxOpacity,
      durationMs: durationMs,
      child: child,
    );
  }

  /// 聊天消息进入：从对应方向滑入
  static Widget messageEnter(
    Widget child, {
    required bool isUser,
    int delayMs = 0,
  }) {
    return child
        .animate(delay: delayMs.ms)
        .fadeIn(duration: 250.ms)
        .slideX(
          begin: isUser ? 0.15 : -0.15,
          end: 0,
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }

  /// 触发一次轻微震动反馈
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }
}

class _BreathingWidget extends StatefulWidget {
  final Widget child;
  final double minOpacity;
  final double maxOpacity;
  final int durationMs;

  const _BreathingWidget({
    required this.child,
    required this.minOpacity,
    required this.maxOpacity,
    required this.durationMs,
  });

  @override
  State<_BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<_BreathingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = widget.minOpacity +
            (widget.maxOpacity - widget.minOpacity) * _animation.value;
        return Opacity(opacity: opacity, child: child);
      },
      child: widget.child,
    );
  }
}
