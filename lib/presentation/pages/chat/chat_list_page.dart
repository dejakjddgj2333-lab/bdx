import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../domain/entities/conversation.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat_list/chat_list_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/side_menu.dart';

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
      body: BlocConsumer<AuthBloc, AuthState>(
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
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: Icon(Icons.menu, color: colors.text),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => setState(() => _showSearch = !_showSearch),
                    icon: Icon(_showSearch ? Icons.close : Icons.search, color: colors.text),
                  ),
                  IconButton(
                    onPressed: () => context.push('/chat/detail'),
                    icon: Icon(Icons.add_circle_outline, color: colors.text),
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
    final colors = AppColors.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildQuickActions(context)),
        if (_showSearch)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildSearchField(),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                const SizedBox(width: 8),
                Text(
                  '最近对话',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildConversationList(),
      ],
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.glassWhite,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.lock_outline, color: colors.textTertiary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              '登录后查看对话记录',
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '立即登录，开启 AI 对话',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  '立即登录',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => context.read<ChatListBloc>().add(ChatListSearchChanged(value)),
        style: TextStyle(color: colors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索会话',
          hintStyle: TextStyle(color: colors.textTertiary),
          prefixIcon: Icon(Icons.search, color: colors.textTertiary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    context.read<ChatListBloc>().add(const ChatListSearchChanged(''));
                    setState(() {});
                  },
                  icon: Icon(Icons.clear, color: colors.textTertiary, size: 20),
                )
              : null,
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
          const SizedBox(width: 12),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
            child: Center(
              child: Text(state.message, style: TextStyle(color: colors.textSecondary)),
            ),
          );
        }
        if (state is ChatListLoadedSuccess) {
          final conversations = state.searchQuery.isEmpty ? state.conversations : state.filtered;

          if (conversations.isEmpty) {
            return SliverFillRemaining(
              child: _buildEmptyState(),
            );
          }

          final grouped = _groupConversations(conversations);

          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = grouped.entries.elementAt(index);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ...entry.value.map((c) => _buildConversationItem(context, c)),
                    ],
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

  Widget _buildEmptyState() {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.glassWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.chat_bubble_outline, color: colors.textTertiary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无会话',
            style: TextStyle(color: colors.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角新建对话',
            style: TextStyle(color: colors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Map<String, List<Conversation>> _groupConversations(List<Conversation> list) {
    final result = <String, List<Conversation>>{};
    for (final c in list) {
      final label = app_date_utils.DateUtils.groupLabel(c.updatedAt ?? c.createdAt ?? DateTime.now());
      result.putIfAbsent(label, () => []).add(c);
    }
    return result;
  }

  Widget _buildConversationItem(BuildContext context, Conversation conversation) {
    final colors = AppColors.of(context);
    final bloc = context.read<ChatListBloc>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
        child: GestureDetector(
          onTap: () => context.push('/chat/detail?id=${conversation.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.glassWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
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
                      const SizedBox(height: 4),
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
                  app_date_utils.DateUtils.formatTime(conversation.updatedAt ?? conversation.createdAt ?? DateTime.now()),
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Conversation conversation, ChatListBloc bloc) {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              bloc.add(ChatListConversationRenamed(conversation.id!, controller.text.trim()));
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Conversation conversation, ChatListBloc bloc) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
