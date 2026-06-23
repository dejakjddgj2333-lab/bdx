import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../blocs/meeting/meeting_cubit.dart';
import '../../blocs/meeting/meeting_state.dart';
import '../bdx/press_scale.dart';

/// 会议内聊天面板：玻璃拟态底部弹层，DataChannel 实时收发，仅本次会议有效。
class MeetingChatPanel extends StatefulWidget {
  const MeetingChatPanel({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<MeetingCubit>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const MeetingChatPanel(),
      ),
    );
  }

  @override
  State<MeetingChatPanel> createState() => _MeetingChatPanelState();
}

class _MeetingChatPanelState extends State<MeetingChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<MeetingCubit>().sendChatMessage(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: colors.meetingGlassBg.withValues(alpha: 0.9),
              border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        Text('聊天',
                            style: AppTextStyles.title(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(width: 8),
                        Text('· 消息仅本次会议可见',
                            style: AppTextStyles.captionSmall(context)
                                .copyWith(color: Colors.white38)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: BlocConsumer<MeetingCubit, MeetingState>(
                      listenWhen: (a, b) =>
                          a.messages.length != b.messages.length,
                      listener: (_, state) => WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToBottom()),
                      builder: (context, state) {
                        if (state.messages.isEmpty) {
                          return Center(
                            child: Text('还没有消息，发个招呼吧',
                                style: AppTextStyles.caption(context)
                                    .copyWith(color: Colors.white38)),
                          );
                        }
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          itemCount: state.messages.length,
                          itemBuilder: (context, i) =>
                              _MessageBubble(message: state.messages[i]),
                        );
                      },
                    ),
                  ),
                  _buildInputBar(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: Colors.white,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _send(context),
                decoration: const InputDecoration(
                  hintText: '说点什么…',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                  // 外层 Container 已绘制边框；这里必须把所有状态边框都关掉，
                  // 否则会回退到全局 inputDecorationTheme 的描边，形成双边框。
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PressScale(
            onTap: () => _send(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MeetingChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.isLocal;
    final avatar = _ChatAvatar(
      name: message.senderName,
      avatarUrl: message.senderAvatar,
    );
    final bubble = Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(message.senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.captionSmall(context)
                  .copyWith(color: Colors.white54)),
        ),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.62,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: mine ? AppColors.primaryGradient : null,
            color: mine ? null : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Text(message.text,
              style:
                  AppTextStyles.body(context).copyWith(color: Colors.white)),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mine
            ? [
                Flexible(child: bubble),
                const SizedBox(width: 8),
                avatar,
              ]
            : [
                avatar,
                const SizedBox(width: 8),
                Flexible(child: bubble),
              ],
      ),
    );
  }
}

/// 聊天头像：有头像 URL 时显示网络图（相对路径自动补全），否则用彩色首字母。
class _ChatAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  static const double _size = 34;

  const _ChatAvatar({required this.name, this.avatarUrl});

  String? get _resolvedUrl {
    final url = avatarUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConstants.uploadBaseUrl.replaceAll(RegExp(r'/$'), '')}$url';
  }

  Color get _color {
    const colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.pink,
      AppColors.success,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedUrl;
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final fallback = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color.withValues(alpha: 0.85),
      ),
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    );

    if (resolved == null) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: _size,
        height: _size,
        memCacheWidth: (_size * 2).toInt(),
        memCacheHeight: (_size * 2).toInt(),
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
