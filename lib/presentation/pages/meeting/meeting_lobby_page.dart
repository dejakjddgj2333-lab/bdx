import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/bdx/press_scale.dart';

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
      backgroundColor: const Color(0xFF07060F),
      body: Stack(
        children: [
          // 深空背景渐变 + 星点装饰
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, -0.9),
                  radius: 1.4,
                  colors: [Color(0xFF1A153A), Color(0xFF07060F)],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _StarField()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCreateCard(),
                        const SizedBox(height: 22),
                        const _OrDivider(),
                        const SizedBox(height: 22),
                        _buildJoinCard(),
                      ],
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PressScale(
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
          ),
          const Text(
            '视频会议',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 发起会议 卡片 =====
  Widget _buildCreateCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        image: const DecorationImage(
          image: AssetImage('assets/images/meeting_create_bg.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C4BE0).withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                  ),
                  child: const Icon(Icons.videocam,
                      color: Colors.white, size: 23),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('发起会议',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('创建一个新的会议',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 主题输入框（透明背景 + 边框）
            _GlassInput(
              controller: _titleController,
              hint: '会议主题（可选）',
              icon: Icons.edit_outlined,
              borderColor: Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            // 创建按钮（白底紫字胶囊）
            PressScale(
              onTap: _createMeeting,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.videocam, color: Color(0xFF5B43D6), size: 18),
                    SizedBox(width: 6),
                    Text('创建并进入会议',
                        style: TextStyle(
                            color: Color(0xFF5B43D6),
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 加入会议 卡片 =====
  Widget _buildJoinCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF181C2E), Color(0xFF12141F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B8DEF), Color(0xFF3A6BE0)],
                  ),
                ),
                child: const Icon(Icons.groups, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('加入会议',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('加入已有的会议',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
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
          ),
          const SizedBox(height: 12),
          PressScale(
            onTap: _joinMeeting,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF4F8BFF), width: 1.5),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4F8BFF).withValues(alpha: 0.18),
                    const Color(0xFF6C4BE0).withValues(alpha: 0.12),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F8BFF).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.login, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('加入会议',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 复用：玻璃输入框 =====
class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Widget? iconWidget;
  final Color borderColor;

  const _GlassInput({
    required this.controller,
    required this.hint,
    this.icon,
    this.iconWidget,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: iconWidget ??
                    Icon(icon, color: Colors.white54, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: hint,
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
            color: const Color(0xFF7E6BF0),
          ),
        );
    return Row(
      children: [
        line([Colors.transparent, Colors.white.withValues(alpha: 0.25)]),
        const SizedBox(width: 8),
        diamond(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('或',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        diamond(),
        const SizedBox(width: 8),
        line([Colors.white.withValues(alpha: 0.25), Colors.transparent]),
      ],
    );
  }
}

// ===== 背景星点 =====
class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter());
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

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (final s in _stars) {
      canvas.drawCircle(
        Offset(s[0] * size.width, s[1] * size.height),
        s[2],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
