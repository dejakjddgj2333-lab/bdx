import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/bdx/bdx_button.dart';
import '../../widgets/bdx/press_scale.dart';
import '../../widgets/meeting/space_background.dart';

class MeetingLobbyPage extends StatefulWidget {
  const MeetingLobbyPage({super.key});

  @override
  State<MeetingLobbyPage> createState() => _MeetingLobbyPageState();
}

class _MeetingLobbyPageState extends State<MeetingLobbyPage> {
  final _titleController = TextEditingController();
  final _roomController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _createMeeting() {
    final title = _titleController.text.trim();
    context.push('/meeting/room', extra: {
      'action': 'create',
      'title': title,
    });
  }

  void _joinMeeting() {
    final room = _roomController.text.trim();
    if (room.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入会议号')),
      );
      return;
    }
    context.push('/meeting/room', extra: {
      'action': 'join',
      'roomName': room,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: Stack(
        children: [
          // 深空背景渐变 + 星点装饰（与会议室内一致）
          const Positioned.fill(child: SpaceBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    child: AnimationLimiter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCreateCard(),
                          const SizedBox(height: 22),
                          const _OrDivider(),
                          const SizedBox(height: 22),
                          _buildJoinCard(),
                        ]
                            .asMap()
                            .entries
                            .map((e) => AnimationConfiguration.staggeredList(
                                  position: e.key,
                                  duration: const Duration(milliseconds: 700),
                                  child: SlideAnimation(
                                    verticalOffset: 40,
                                    child: FadeInAnimation(child: e.value),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          PressScale(
            onTap: () => context.pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          const Spacer(),
          Text(
            '视频会议',
            style: AppTextStyles.titleLarge(context).copyWith(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  // ===== 发起会议 卡片 =====
  Widget _buildCreateCard() {
    return _GradientBorderCard(
      glowColor: AppColors.primaryGlow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35)),
                    boxShadow: AppShadows.avatarGlow(
                      AppColors.primaryLight,
                      opacity: 0.3,
                    ),
                  ),
                  child: const Icon(Icons.videocam,
                      color: Colors.white, size: 23),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('发起会议',
                        style: AppTextStyles.title(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 2),
                    Text('创建一个新的会议',
                        style: AppTextStyles.bodySmall(context)
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GlassInput(
              controller: _titleController,
              hint: '会议主题（可选）',
              icon: Icons.edit_outlined,
              borderColor: Colors.white.withValues(alpha: 0.45),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createMeeting(),
            ),
            const SizedBox(height: 12),
            BdxButton(
              text: '创建并进入会议',
              icon: Icons.videocam,
              type: BdxButtonType.primary,
              expanded: true,
              height: 46,
              onTap: _createMeeting,
            ),
          ],
        ),
      ),
    );
  }

  // ===== 加入会议 卡片 =====
  Widget _buildJoinCard() {
    return _GradientBorderCard(
      borderColors: const [Color(0xFF4F8BFF), Color(0xFF6C4BE0)],
      glowColor: const Color(0xFF4F8BFF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5B8DEF), Color(0xFF3A6BE0)],
                    ),
                    boxShadow: AppShadows.avatarGlow(
                      const Color(0xFF4F8BFF),
                      opacity: 0.35,
                    ),
                  ),
                  child: const Icon(Icons.groups, color: Colors.white, size: 23),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('加入会议',
                        style: AppTextStyles.title(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 2),
                    Text('加入已有的会议',
                        style: AppTextStyles.bodySmall(context)
                            .copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GlassInput(
              controller: _roomController,
              hint: '输入会议号',
              iconWidget: const Text('#',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              borderColor: Colors.white.withValues(alpha: 0.18),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _joinMeeting(),
            ),
            const SizedBox(height: 12),
            BdxButton(
              text: '加入会议',
              icon: Icons.login,
              type: BdxButtonType.secondary,
              expanded: true,
              height: 46,
              onTap: _joinMeeting,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 复用：玻璃输入框（聚焦发光） =====
class _GlassInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Widget? iconWidget;
  final Color borderColor;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _GlassInput({
    required this.controller,
    required this.hint,
    this.icon,
    this.iconWidget,
    required this.borderColor,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<_GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<_GlassInput> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.primaryLight.withValues(alpha: 0.7)
              : widget.borderColor,
          width: _focused ? 1.6 : 1.2,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primaryGlow.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: widget.iconWidget ??
                      Icon(widget.icon, color: Colors.white54, size: 18),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: Colors.white,
                    textInputAction: widget.textInputAction,
                    onSubmitted: widget.onSubmitted,
                    onTapOutside: (_) => _focusNode.unfocus(),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== 渐变边框玻璃卡片 =====
class _GradientBorderCard extends StatelessWidget {
  final Widget child;
  final List<Color>? borderColors;
  final Color glowColor;

  const _GradientBorderCard({
    required this.child,
    this.borderColors,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x18FFFFFF), Color(0x06FFFFFF)],
        ),
        boxShadow: [
          ...AppShadows.card(context),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.18),
            blurRadius: 30,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // 顶部高光
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          (borderColors?.first ?? Colors.white).withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== “或” 分隔线（带菱形点缀） =====
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    Widget line(List<Color> colors) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
            ),
          ),
        );
    Widget diamond() => Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF7E6BF0),
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7E6BF0).withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        line([Colors.transparent, Colors.white.withValues(alpha: 0.25)]),
        const SizedBox(width: 8),
        diamond(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('或',
              style: AppTextStyles.body(context)
                  .copyWith(color: Colors.white70)),
        ),
        diamond(),
        const SizedBox(width: 8),
        line([Colors.white.withValues(alpha: 0.25), Colors.transparent]),
      ],
    );
  }
}

// ===== 背景星点已抽离至 SpaceBackground（widgets/meeting/space_background.dart） =====
