import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat_list/chat_list_bloc.dart';
import '../../blocs/model/model_cubit.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/conversation_list_body.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/side_menu.dart';
import '../../widgets/tech_background.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _hasRequestedList = false;
  final _homeInputController = TextEditingController();

  @override
  void dispose() {
    _homeInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      drawer: const SideMenu(),
      body: TechBackground(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, authState) {
            if (authState is AuthAuthenticated && !_hasRequestedList) {
              _hasRequestedList = true;
              context.read<ChatListBloc>().add(const ChatListLoaded());
              context.read<ModelCubit>().loadModels();
            }
          },
          builder: (context, authState) {
            return Column(
              children: [
                AppHeader(
                  leading: Builder(
                    builder: (context) => BdxIconButton(
                      icon: Icons.menu,
                      onTap: () => Scaffold.of(context).openDrawer(),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  actions: [
                    BdxIconButton(
                      icon: Icons.add_circle_outline,
                      onTap: () => context.push('/chat/detail'),
                      backgroundColor: Colors.transparent,
                    ),
                  ],
                ),
                Expanded(
                  child: _buildBody(authState),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(AuthState authState) {
    if (authState is AuthInitial || authState is AuthLoading) {
      return const Center(child: LoadingIndicator());
    }
    if (authState.isAuthenticated) {
      return _buildAuthenticatedBody(context);
    }
    return _buildLoginPrompt(context);
  }

  Widget _buildAuthenticatedBody(BuildContext context) {
    return LiquidPullToRefresh(
      onRefresh: () async {
        context.read<ChatListBloc>().add(const ChatListLoaded());
      },
      color: AppColors.primary,
      backgroundColor: Colors.white,
      height: 60,
      showChildOpacityTransition: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context)),
          SliverToBoxAdapter(child: _buildHomeInput(context)),
          SliverToBoxAdapter(child: _buildVoiceCard(context)),
          SliverToBoxAdapter(child: _buildMeetingCard(context)),
          SliverToBoxAdapter(child: _buildQuickGrid(context)),
          _buildConversationList(),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return BdxEmptyState(
      icon: Icons.lock_outline,
      title: '登录后查看对话记录',
      subtitle: '立即登录，开启 AI 对话',
      illustration: const BdxEmptyIllustration(size: 160),
      action: BdxButton(
        text: '立即登录',
        expanded: true,
        onTap: () => context.go('/login'),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        AppDimens.s8,
        AppDimens.s16,
        AppDimens.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.primaryGradient
                      .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '北斗星AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.s10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '你好，我是你的 AI 伙伴',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    softWrap: false,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: AppDimens.s2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '今天想聊点什么？',
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    softWrap: false,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          _buildMascot(maxWidth: 250),
        ],
      ),
    );
  }

  Widget _buildMascot({required double maxWidth}) {
    final scale = maxWidth / 250;

    return SizedBox(
      width: maxWidth,
      height: 180 * scale,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 250,
          height: 180,
          child: BdxEmptyIllustration(size: 160 * scale.clamp(0.7, 1.2)),
        ),
      ),
    );
  }

  Widget _buildHomeInput(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        AppDimens.s4,
        AppDimens.s16,
        AppDimens.s12,
      ),
      child: BdxInput(
        controller: _homeInputController,
        hintText: '输入消息，开启文字对话...',
        textInputAction: TextInputAction.send,
        onSubmitted: _submitHomeInput,
        suffix: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _homeInputController,
          builder: (context, value, child) {
            final hasText = value.text.trim().isNotEmpty;
            return BdxIconButton(
              icon: Icons.send,
              size: 44,
              backgroundColor: hasText ? AppColors.primary : colors.glassWhite,
              iconColor: hasText ? Colors.white : colors.textTertiary,
              onTap: hasText ? _submitHomeInput : null,
            );
          },
        ),
      ),
    );
  }

  void _submitHomeInput() {
    final text = _homeInputController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    _homeInputController.clear();
    context.push('/chat/detail?content=${Uri.encodeComponent(text)}');
  }

  Widget _buildVoiceCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        AppDimens.s4,
        AppDimens.s16,
        AppDimens.s16,
      ),
      child: PressScale(
        onTap: () => context.push('/voice-call'),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.s16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppDimens.r18),
            boxShadow: AppShadows.glowPrimary(opacity: 0.3),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppDimens.s14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '开始语音对话',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppDimens.s4),
                    Text(
                      '与 AI 实时语音交流',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const _VoiceWaveBars(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        0,
        AppDimens.s16,
        AppDimens.s16,
      ),
      child: PressScale(
        onTap: () => context.push('/meeting'),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.s16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4FACFE), Color(0xFF00C2FF)],
            ),
            borderRadius: BorderRadius.circular(AppDimens.r18),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppDimens.s14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '视频会议',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppDimens.s4),
                    Text(
                      '发起或加入多人音视频会议',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickGrid(BuildContext context) {
    final items = const [
      _QuickItem(
        icon: Icons.smart_toy_outlined,
        title: 'AI 助手',
        subtitle: '智能问答',
        color: AppColors.primaryLight,
      ),
      _QuickItem(
        icon: Icons.brush_outlined,
        title: 'AI 绘图',
        subtitle: '创意绘画',
        color: Color(0xFF4FACFE),
      ),
      _QuickItem(
        icon: Icons.edit_note_outlined,
        title: 'AI 写作',
        subtitle: '文案创作',
        color: AppColors.success,
      ),
      _QuickItem(
        icon: Icons.work_outline_outlined,
        title: '实用工具',
        subtitle: '效率提升',
        color: Color(0xFFFFA726),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        0,
        AppDimens.s16,
        AppDimens.s16,
      ),
      child: SizedBox(
        height: 108,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _buildQuickCard(context, items[i])),
              if (i < items.length - 1) const SizedBox(width: AppDimens.s10),
            ],
          ],
        ),
      ),
    );
  }

  void _onQuickItemTap(BuildContext context, _QuickItem item) {
    switch (item.title) {
      case 'AI 助手':
        context.push('/chat/detail?scene=assistant');
      case 'AI 绘图':
        context.push('/image-generation');
      case 'AI 写作':
        context.push('/chat/detail?scene=rewrite');
      case '实用工具':
        context.push('/tools');
    }
  }

  Widget _buildQuickCard(BuildContext context, _QuickItem item) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: () => _onQuickItemTap(context, item),
      child: GlassCard(
        borderRadius: AppDimens.r16,
        padding: const EdgeInsets.all(AppDimens.s10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.color.withValues(alpha: 0.9),
                    item.color.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppDimens.r10),
              ),
              child: Icon(
                item.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: AppDimens.s8),
            Text(
              item.title,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.s2),
            Text(
              item.subtitle,
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    return BlocBuilder<ChatListBloc, ChatListState>(
      builder: (context, state) {
        final colors = AppColors.of(context);

        if (state is ChatListLoading) {
          return const SliverFillRemaining(
            child: Center(
              child: BdxTypingDots(dotSize: 10, color: AppColors.primaryLight),
            ),
          );
        }
        if (state is ChatListError) {
          return SliverFillRemaining(
            child: BdxEmptyState(
              icon: Icons.error_outline,
              title: '加载失败',
              subtitle: state.message,
              action: BdxButton(
                text: '重试',
                onTap: () => context.read<ChatListBloc>().add(const ChatListLoaded()),
              ),
            ),
          );
        }
        if (state is ChatListLoadedSuccess) {
          final conversations = state.searchQuery.isEmpty
              ? state.conversations
              : state.filtered;

          if (conversations.isEmpty) {
            return SliverFillRemaining(
              child: BdxEmptyState(
                icon: Icons.chat_bubble_outline,
                title: '暂无会话',
                subtitle: '点击右上角新建对话',
              ),
            );
          }

          final recent = conversations.take(5).toList();
          final hasMore = conversations.length > 5;

          return SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: AppDimens.sectionPadding,
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: AppDimens.s8),
                      Text(
                        '最近对话',
                        style: AppTextStyles.titleSmall(context),
                      ),
                      const Spacer(),
                      if (hasMore)
                        GestureDetector(
                          onTap: () => context.push('/chat/history'),
                          child: Text(
                            '查看更多 >',
                            style: TextStyle(
                              color: colors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 首页仅展示最近 5 条会话，数量可控，使用 shrinkWrap 避免嵌套滚动冲突。
                // 若后续展示数量显著增加，应改为 SliverList.separated。
                ConversationListBody(
                  conversations: recent,
                  bloc: context.read<ChatListBloc>(),
                  shrinkWrap: true,
                  showGroupHeaders: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.s16,
                  ),
                ),
              ],
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _QuickItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _VoiceWaveBars extends StatelessWidget {
  const _VoiceWaveBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _bar(10),
        const SizedBox(width: 4),
        _bar(22),
        const SizedBox(width: 4),
        _bar(16),
        const SizedBox(width: 4),
        _bar(28),
      ],
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

