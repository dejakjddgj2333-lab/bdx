import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../domain/entities/conversation.dart';
import '../../blocs/chat_list/chat_list_bloc.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/conversation_list_body.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/tech_background.dart';
import '../../../injection.dart';

class ConversationHistoryPage extends StatefulWidget {
  const ConversationHistoryPage({super.key});

  @override
  State<ConversationHistoryPage> createState() => _ConversationHistoryPageState();
}

class _ConversationHistoryPageState extends State<ConversationHistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    context.read<ChatListBloc>().add(ChatListSearchChanged(value));
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    if (_searchQuery.isEmpty) return conversations;
    final query = _searchQuery.toLowerCase();
    return conversations
        .where((c) => c.title?.toLowerCase().contains(query) ?? false)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: TechBackground(
        child: BlocProvider(
          create: (_) => getIt<ChatListBloc>()..add(const ChatListLoaded()),
          child: Column(
            children: [
              AppHeader(
                title: '历史记录',
                leading: BdxIconButton(
                  icon: Icons.arrow_back_ios_new,
                  onTap: () => context.pop(),
                  backgroundColor: Colors.transparent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.s16,
                  0,
                  AppDimens.s16,
                  AppDimens.s12,
                ),
                child: BdxInput(
                  controller: _searchController,
                  hintText: '搜索会话',
                  prefix: Icon(
                    Icons.search,
                    color: colors.textTertiary,
                    size: AppDimens.iconMedium,
                  ),
                  suffix: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: Icon(
                            Icons.clear,
                            color: colors.textTertiary,
                            size: AppDimens.iconMedium,
                          ),
                        )
                      : null,
                  onChanged: _onSearchChanged,
                ),
              ),
              Expanded(
                child: BlocBuilder<ChatListBloc, ChatListState>(
                  builder: (context, state) {
                    if (state is ChatListLoading) {
                      return const Center(child: LoadingIndicator());
                    }
                    if (state is ChatListError) {
                      return BdxEmptyState(
                        icon: Icons.error_outline,
                        title: '加载失败',
                        subtitle: state.message,
                        action: BdxButton(
                          text: '重试',
                          onTap: () => context
                              .read<ChatListBloc>()
                              .add(const ChatListLoaded()),
                        ),
                      );
                    }
                    if (state is ChatListLoadedSuccess) {
                      final conversations = _filterConversations(state.conversations);

                      if (conversations.isEmpty) {
                        final isSearching = _searchQuery.isNotEmpty;
                        return BdxEmptyState(
                          icon: isSearching ? Icons.search_off : Icons.chat_bubble_outline,
                          title: isSearching ? '未找到匹配会话' : '暂无会话',
                          subtitle: isSearching ? '换个关键词试试' : '点击右下角新建对话',
                          illustration: const BdxEmptyIllustration(size: 160),
                        );
                      }

                      return ConversationListBody(
                        conversations: conversations,
                        bloc: context.read<ChatListBloc>(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.s16,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
