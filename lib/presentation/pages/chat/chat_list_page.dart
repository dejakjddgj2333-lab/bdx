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
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (context.read<AuthBloc>().state.isAuthenticated) {
      context.read<ChatListBloc>().add(const ChatListLoaded());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: const SideMenu(),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return Column(
            children: [
              AppHeader(
                title: '北斗星AI',
                leading: Builder(
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu, color: Colors.white),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => setState(() => _showSearch = !_showSearch),
                    icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => context.go('/chat/detail'),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  ),
                ],
              ),
              Expanded(
                child: authState.isAuthenticated
                    ? _buildAuthenticatedBody(context)
                    : _buildLoginPrompt(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthenticatedBody(BuildContext context) {
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
                const Text(
                  '最近对话',
                  style: TextStyle(
                    color: Colors.white,
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
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.lock_outline, color: AppColors.textTertiary, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              '登录后查看对话记录',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '立即登录，开启 AI 对话',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => context.read<ChatListBloc>().add(ChatListSearchChanged(value)),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索会话',
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    context.read<ChatListBloc>().add(const ChatListSearchChanged(''));
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear, color: AppColors.textTertiary, size: 20),
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
              onTap: () => context.go('/agents'),
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
              onTap: () => context.go('/voice-call'),
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
        if (state is ChatListLoading) {
          return const SliverFillRemaining(
            child: Center(child: LoadingIndicator()),
          );
        }
        if (state is ChatListError) {
          return SliverFillRemaining(
            child: Center(
              child: Text(state.message, style: const TextStyle(color: AppColors.textSecondary)),
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
                          style: const TextStyle(
                            color: AppColors.textTertiary,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.chat_bubble_outline, color: AppColors.textTertiary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无会话',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右上角新建对话',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
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
          onTap: () => context.go('/chat/detail?id=${conversation.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSubtle),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.model ?? '默认模型',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  app_date_utils.DateUtils.formatTime(conversation.updatedAt ?? conversation.createdAt ?? DateTime.now()),
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Conversation conversation, ChatListBloc bloc) {
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('重命名会话', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '会话名称'),
          style: const TextStyle(color: Colors.white),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除会话', style: TextStyle(color: Colors.white)),
        content: const Text(
          '确定删除该会话吗？删除后不可恢复。',
          style: TextStyle(color: AppColors.textSecondary),
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
