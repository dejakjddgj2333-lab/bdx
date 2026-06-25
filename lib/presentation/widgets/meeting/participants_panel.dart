import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../blocs/meeting/meeting_cubit.dart';
import '../../blocs/meeting/meeting_state.dart';
import '../bdx/press_scale.dart';
import 'participant_avatar.dart';

/// 参会成员面板：玻璃拟态底部弹层，实时展示成员、静音/举手/主持人状态。
/// 主持人可放下他人或全体的手。
class MeetingParticipantsPanel extends StatelessWidget {
  const MeetingParticipantsPanel({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<MeetingCubit>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const MeetingParticipantsPanel(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1530).withValues(alpha: 0.9),
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          ),
          child: SafeArea(
            top: false,
            child: BlocBuilder<MeetingCubit, MeetingState>(
              builder: (context, state) {
                final cubit = context.read<MeetingCubit>();
                final entries = <_MemberEntry>[];
                final local = state.localParticipant;
                if (local != null) {
                  entries.add(_MemberEntry(
                    participant: local,
                    isLocal: true,
                    isHost: state.isHost,
                    avatarUrl: cubit.avatarOf(local),
                  ));
                }
                for (final r in state.remoteParticipants) {
                  entries.add(_MemberEntry(
                    participant: r,
                    isLocal: false,
                    isHost: false,
                    avatarUrl: cubit.avatarOf(r),
                  ));
                }
                final raisedCount = state.raisedHands.length;

                return Column(
                  mainAxisSize: MainAxisSize.min,
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
                      padding:
                          const EdgeInsets.fromLTRB(20, 4, 12, 8),
                      child: Row(
                        children: [
                          Text('参会成员 (${entries.length})',
                              style: AppTextStyles.title(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              )),
                          const Spacer(),
                          if (state.isHost && raisedCount > 0)
                            PressScale(
                              onTap: () => cubit.lowerHandFor(null),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.6)),
                                ),
                                child: Text('全体放下手',
                                    style: AppTextStyles.caption(context)
                                        .copyWith(color: AppColors.accent)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final entry = entries[i];
                          final id = entry.participant.identity;
                          return _MemberTile(
                            entry: entry,
                            raised: state.raisedHands.contains(id),
                            canManage: state.isHost,
                            canPublish:
                                entry.participant.permissions.canPublish,
                            onLower: () => cubit.lowerHandFor(id),
                            onApprove: () => cubit.approveHand(id),
                            onTogglePublish: (allow) =>
                                cubit.setPublishPermission(id, allow),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberEntry {
  final Participant participant;
  final bool isLocal;
  final bool isHost;
  final String? avatarUrl;

  _MemberEntry({
    required this.participant,
    required this.isLocal,
    required this.isHost,
    this.avatarUrl,
  });
}

class _MemberTile extends StatelessWidget {
  final _MemberEntry entry;
  final bool raised;
  final bool canManage;

  /// 该成员当前是否有发布（说话/视频/共享）权限。
  final bool canPublish;
  final VoidCallback onLower;

  /// 主持人同意该成员举手发言（授权 + 放下手）。
  final VoidCallback onApprove;

  /// 主持人授予(true)/收回(false)该成员发布权限。
  final ValueChanged<bool> onTogglePublish;

  const _MemberTile({
    required this.entry,
    required this.raised,
    required this.canManage,
    required this.canPublish,
    required this.onLower,
    required this.onApprove,
    required this.onTogglePublish,
  });

  String get _name {
    final n = entry.participant.name.isNotEmpty
        ? entry.participant.name
        : entry.participant.identity;
    return entry.isLocal ? '$n（我）' : n;
  }

  Color get _avatarColor {
    const colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.pink,
      AppColors.success,
    ];
    return colors[_name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final muted = entry.participant.isMuted;
    // 主持人始终有权限；仅对「非主持人、非自己」的成员展示权限管理。
    final showHostControls = canManage && !entry.isHost && !entry.isLocal;
    // 非主持人且无发布权限 → 仅观看
    final viewerOnly = !entry.isHost && !canPublish;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _avatarColor.withValues(alpha: 0.85),
            child: ParticipantAvatar(
              name: _name,
              avatarUrl: entry.avatarUrl,
              size: 36,
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(context)
                              .copyWith(color: Colors.white)),
                    ),
                    if (entry.isHost) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.workspace_premium,
                          size: 14, color: AppColors.accent),
                    ],
                  ],
                ),
                if (viewerOnly)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('仅观看',
                        style: AppTextStyles.captionSmall(context)
                            .copyWith(color: Colors.white38)),
                  ),
              ],
            ),
          ),
          if (raised) ...[
            const Icon(Icons.pan_tool, size: 16, color: AppColors.accent),
            const SizedBox(width: 12),
          ],
          Icon(
            muted ? Icons.mic_off : Icons.mic,
            size: 16,
            color: muted ? Colors.redAccent : Colors.white54,
          ),
          if (showHostControls) ...[
            const SizedBox(width: 12),
            if (raised && !canPublish) ...[
              _actionChip(
                context,
                label: '同意',
                primary: true,
                onTap: onApprove,
              ),
              const SizedBox(width: 8),
              _actionChip(
                context,
                label: '放下',
                primary: false,
                onTap: onLower,
              ),
            ] else
              _actionChip(
                context,
                label: canPublish ? '收回权限' : '允许发言',
                primary: !canPublish,
                onTap: () => onTogglePublish(!canPublish),
              ),
          ],
        ],
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required String label,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary
                ? AppColors.accent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Text(label,
            style: AppTextStyles.captionSmall(context).copyWith(
              color: primary ? AppColors.accent : Colors.white70,
            )),
      ),
    );
  }
}
