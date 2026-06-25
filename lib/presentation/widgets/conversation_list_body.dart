import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../domain/entities/conversation.dart';
import '../blocs/chat_list/chat_list_bloc.dart';
import 'bdx/bdx.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;

/// 会话列表视图
///
/// 按时间分组显示会话，支持侧滑重命名/删除。
/// 可在首页（shrinkWrap）和历史记录页复用。
class ConversationListBody extends StatelessWidget {
  final List<Conversation> conversations;
  final ChatListBloc bloc;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final bool showGroupHeaders;

  const ConversationListBody({
    super.key,
    required this.conversations,
    required this.bloc,
    this.shrinkWrap = false,
    this.padding,
    this.showGroupHeaders = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_ListItem>[];
    if (showGroupHeaders) {
      final grouped = _groupConversations(conversations);
      for (final entry in grouped.entries) {
        items.add(_ListItem.header(entry.key));
        for (final c in entry.value) {
          items.add(_ListItem.conversation(c));
        }
      }
    } else {
      for (final c in conversations) {
        items.add(_ListItem.conversation(c));
      }
    }

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: padding ?? EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppDimens.s10),
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.only(
              top: AppDimens.s16,
              bottom: AppDimens.s2,
            ),
            child: Text(
              item.label!,
              style: TextStyle(
                color: AppColors.of(context).textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
        return _buildConversationItem(context, item.conversation!);
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

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.6,
        children: [
          SlidableAction(
            onPressed: (_) => _showRenameDialog(context, conversation),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: '重命名',
          ),
          SlidableAction(
            onPressed: (_) => _showDeleteDialog(context, conversation),
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
    );
  }

  void _showRenameDialog(BuildContext context, Conversation conversation) {
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
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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

  void _showDeleteDialog(BuildContext context, Conversation conversation) {
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

class _ListItem {
  final bool isHeader;
  final String? label;
  final Conversation? conversation;

  const _ListItem.header(this.label)
      : isHeader = true,
        conversation = null;

  const _ListItem.conversation(this.conversation)
      : isHeader = false,
        label = null;
}
