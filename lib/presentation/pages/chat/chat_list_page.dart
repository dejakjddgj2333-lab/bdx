import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/conversation.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat_list/chat_list_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/side_menu.dart';
import '../../widgets/tech_background.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _showSearch = false;
  bool _hasRequestedList = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
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
            }
          },
          builder: (context, authState) {
            return Column(
              children: [
                AppHeader(
                  title: '北斗星AI',
                  leading: Builder(
                    builder: (context) => BdxIconButton(
                      icon: Icons.menu,
                      onTap: () => Scaffold.of(context).openDrawer(),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  actions: [
                    BdxIconButton(
                      icon: _showSearch ? Icons.close : Icons.search,
                      onTap: () => setState(() => _showSearch = !_showSearch),
                      backgroundColor: Colors.transparent,
                    ),
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
        SliverToBoxAdapter(child: _buildQuickActions(context)),
        if (_showSearch)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.s16,
                0,
                AppDimens.s16,
                AppDimens.s12,
              ),
              child: _buildSearchField(),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
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
              ],
            ),
          ),
        ),
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
      action: BdxButton(
        text: '立即登录',
        expanded: true,
        onTap: () => context.go('/login'),
      ),
    );
  }

  Widget _buildSearchField() {
    return BdxInput(
      controller: _searchController,
      hintText: '搜索会话',
      prefix: Icon(
        Icons.search,
        color: AppColors.of(context).textTertiary,
        size: AppDimens.iconMedium,
      ),
      suffix: _searchController.text.isNotEmpty
          ? IconButton(
              onPressed: () {
                _searchController.clear();
                context.read<ChatListBloc>().add(const ChatListSearchChanged(''));
                setState(() {});
              },
              icon: Icon(
                Icons.clear,
                color: AppColors.of(context).textTertiary,
                size: AppDimens.iconMedium,
              ),
            )
          : null,
      onChanged: (value) =>
          context.read<ChatListBloc>().add(ChatListSearchChanged(value)),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.s16,
        AppDimens.s12,
        AppDimens.s16,
        AppDimens.s16,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.smart_toy_outlined,
              label: '发现智能体',
              gradient: AppColors.primaryGradient,
              onTap: () => context.push('/agents'),
            ),
          ),
          const SizedBox(width: AppDimens.s12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.phone_in_talk_outlined,
              label: '语音对话',
              gradient: const LinearGradient(
                colors: [Color(0xFF00A8B5), Color(0xFF00CEC9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.push('/voice-call'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.s18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppDimens.r18),
          boxShadow: AppShadows.glowPrimary(opacity: 0.25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: AppDimens.iconMedium),
            const SizedBox(width: AppDimens.s8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
            child: Center(child: LoadingIndicator()),
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

          final grouped = _groupConversations(conversations);

          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.s16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = grouped.entries.elementAt(index);
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 30,
                      child: FadeInAnimation(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppDimens.s16,
                                bottom: AppDimens.s8,
                              ),
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  color: colors.textTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ...entry.value.map(
                              (c) => _buildConversationItem(context, c),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: grouped.length,
              ),
            ),
          );
        }
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
    );
  }

  Map<String, List<Conversation>> _groupConversations(List<Conversation> list) {
    final result = <String, List<Conversation>>{};
    for (final c in list) {
      final label = app_date_utils.DateUtils.groupLabel(
        c.updatedAt ?? c.createdAt ?? DateTime.now(),
      );
      result.putIfAbsent(label, () => []).add(c);
    }
    return result;
  }

  Widget _buildConversationItem(BuildContext context, Conversation conversation) {
    final colors = AppColors.of(context);
    final bloc = context.read<ChatListBloc>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.s10),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.6,
          children: [
            SlidableAction(
              onPressed: (_) => _showRenameDialog(context, conversation, bloc),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: '重命名',
            ),
            SlidableAction(
              onPressed: (_) => _showDeleteDialog(context, conversation, bloc),
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: '删除',
            ),
          ],
        ),
        child: PressScale(
          onTap: () => context.push('/chat/detail?id=${conversation.id}'),
          child: GlassCard(
            borderRadius: AppDimens.r18,
            padding: AppDimens.listItemPadding,
            child: Row(
              children: [
                BdxGradientAvatar(
                  size: AppDimens.avatarMedium,
                  borderRadius: AppDimens.r14,
                  icon: Icons.chat_bubble,
                ),
                const SizedBox(width: AppDimens.s14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title ?? '新对话',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.s4),
                      Text(
                        conversation.model ?? '默认模型',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  app_date_utils.DateUtils.formatTime(
                    conversation.updatedAt ??
                        conversation.createdAt ??
                        DateTime.now(),
                  ),
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    Conversation conversation,
    ChatListBloc bloc,
  ) {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.r20),
        ),
        title: Text('重命名会话', style: TextStyle(color: colors.text)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '会话名称'),
          style: TextStyle(color: colors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              bloc.add(ChatListConversationRenamed(
                conversation.id!,
                controller.text.trim(),
              ));
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    Conversation conversation,
    ChatListBloc bloc,
  ) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.r20),
        ),
        title: Text('删除会话', style: TextStyle(color: colors.text)),
        content: Text(
          '确定删除该会话吗？删除后不可恢复。',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              bloc.add(ChatListConversationDeleted(conversation.id!));
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.pink)),
          ),
        ],
      ),
    );
  }
}
