import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../blocs/meeting/meeting_cubit.dart';
import '../../blocs/meeting/meeting_state.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/meeting/chat_panel.dart';
import '../../widgets/meeting/participant_avatar.dart';
import '../../widgets/meeting/participants_panel.dart';
import '../../widgets/meeting/space_background.dart';

class MeetingRoomPage extends StatefulWidget {
  /// action: 'create' | 'join'
  final String action;
  final String? title;
  final String? roomName;

  const MeetingRoomPage({
    super.key,
    required this.action,
    this.title,
    this.roomName,
  });

  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<MeetingCubit>();
    if (widget.action == 'create') {
      cubit.createAndJoin(title: widget.title);
    } else {
      cubit.join(widget.roomName!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onStateChanged(MeetingState state) {}

  Future<void> _confirmLeave(MeetingState state) async {
    final cubit = context.read<MeetingCubit>();
    if (state.isHost) {
      final choice = await _showGlassBottomSheet<String>(
        children: [
          _sheetTile(
            icon: Icons.logout,
            title: '离开会议',
            subtitle: '会议继续，其他人不受影响',
            onTap: () => Navigator.of(context).pop('leave'),
          ),
          _sheetTile(
            icon: Icons.call_end,
            iconColor: Colors.redAccent,
            title: '结束会议',
            titleColor: Colors.redAccent,
            subtitle: '所有人将被移出',
            onTap: () => Navigator.of(context).pop('end'),
          ),
        ],
      );
      if (choice == 'leave') {
        await _runWithLeaving(cubit.leave, '正在离开会议…');
      } else if (choice == 'end') {
        await _runWithLeaving(cubit.endMeeting, '正在结束会议…');
      }
    } else {
      await _runWithLeaving(cubit.leave, '正在离开会议…');
    }
  }

  /// 离开 / 结束会议期间显示不可关闭的 Loading 遮罩，完成后退出页面。
  /// （endMeeting 要走后端 + LiveKit 断连，期间给用户明确反馈，避免像卡死。）
  Future<void> _runWithLeaving(
      Future<void> Function() action, String label) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _LeavingOverlay(label: label),
    );
    try {
      await action();
    } finally {
      if (mounted) {
        // 先关 Loading 弹窗，再退出会议页
        Navigator.of(context, rootNavigator: true).pop();
        context.pop();
      }
    }
  }

  void _showParticipantsPanel() {
    MeetingParticipantsPanel.show(context);
  }

  void _showChatPanel() {
    MeetingChatPanel.show(context);
  }

  /// 无发布权限时点击麦克风/摄像头/共享的提示。
  void _showLockedHint() {
    BdxToast.show(
      context,
      message: '你暂无发言权限，请点击「举手」向主持人申请',
      icon: Icons.lock_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MeetingCubit, MeetingState>(
      listener: (context, state) {
        _onStateChanged(state);
        if (state.status == MeetingStatus.error) {
          BdxToast.show(
            context,
            message: state.errorMessage ?? '会议出错',
            icon: Icons.error_outline,
          );
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _confirmLeave(state);
          },
          child: Scaffold(
            // 透明背景，由 SpaceBackground 提供深空渐变
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                const Positioned.fill(
                  child: SpaceBackground(starOpacity: 0.28),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(state),
                      _buildHandRaiseBanner(state),
                      _buildViewerNotice(state),
                      Expanded(child: _buildBody(state)),
                      _buildControlBar(state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(MeetingState state) {
    final count = state.remoteParticipants.length + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          PressScale(
            onTap: () => _confirmLeave(state),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.call_end,
                  color: Colors.redAccent, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.title ?? '会议',
                          style: AppTextStyles.titleSmall(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PillBadge(
                        icon: Icons.people,
                        label: '$count',
                      ),
                      const SizedBox(width: 6),
                      _MeetingDurationBadge(
                        isRunning: state.status == MeetingStatus.connected,
                      ),
                    ],
                  ),
                  if (state.roomName != null) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: state.roomName!));
                        BdxToast.show(
                          context,
                          message: '会议号已复制',
                          icon: Icons.copy,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text('会议号 ${state.roomName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption(context)
                                    .copyWith(color: Colors.white54)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy,
                              size: 12, color: Colors.white54),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 举手提醒横幅（仅主持人）=====
  Widget _buildHandRaiseBanner(MeetingState state) {
    final localId = state.localParticipant?.identity;
    final raisedRemotes = state.remoteParticipants
        .where((p) =>
            p.identity != localId && state.raisedHands.contains(p.identity))
        .toList();
    final show = state.isHost && raisedRemotes.isNotEmpty;

    Widget content = const SizedBox(width: double.infinity);
    if (show) {
      final first = raisedRemotes.first;
      final firstName = first.name.isNotEmpty ? first.name : first.identity;
      final text = raisedRemotes.length == 1
          ? '$firstName 举手了'
          : '$firstName 等 ${raisedRemotes.length} 人举手';
      content = Padding(
        key: const ValueKey('hand-banner'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 14,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.pan_tool, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (raisedRemotes.length == 1)
                _bannerButton(
                  '同意发言',
                  () => context
                      .read<MeetingCubit>()
                      .approveHand(first.identity),
                )
              else
                _bannerButton('查看', _showParticipantsPanel),
              const SizedBox(width: 8),
              _bannerButton(
                raisedRemotes.length == 1 ? '放下' : '全体放下',
                () => context
                    .read<MeetingCubit>()
                    .lowerHandFor(raisedRemotes.length == 1 ? first.identity : null),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: content,
      ),
    );
  }

  // ===== 仅观看提示横幅（非主持人且无发布权限）=====
  Widget _buildViewerNotice(MeetingState state) {
    final localId = state.localParticipant?.identity;
    final handRaised = localId != null && state.raisedHands.contains(localId);
    final show = state.status == MeetingStatus.connected &&
        !state.isHost &&
        !state.canPublish;

    Widget content = const SizedBox(width: double.infinity);
    if (show) {
      content = Padding(
        key: const ValueKey('viewer-notice'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 18, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  handRaised ? '已举手，等待主持人同意发言' : '你处于仅观看状态，可举手申请发言',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(context)
                      .copyWith(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              _bannerButton(
                handRaised ? '取消举手' : '举手',
                () => context.read<MeetingCubit>().toggleHand(),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: content,
      ),
    );
  }

  Widget _bannerButton(String label, VoidCallback onTap) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.7)),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(context).copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(MeetingState state) {
    if (state.status == MeetingStatus.connecting ||
        state.status == MeetingStatus.initial) {
      return _buildConnectingSplash();
    }

    final cubit = context.read<MeetingCubit>();
    final cameraTiles = <_ParticipantTileData>[];
    final screenTiles = <_ParticipantTileData>[];

    void collect(Participant p,
        {required bool isLocal, required bool isHost, required String name}) {
      cameraTiles.add(_ParticipantTileData(
        participant: p,
        isLocal: isLocal,
        isHost: isHost,
        handRaised: state.raisedHands.contains(p.identity),
        name: name,
        avatarUrl: cubit.avatarOf(p),
        videoTrack: _cameraTrackOf(p),
      ));
      final screen = _screenTrackOf(p);
      if (screen != null) {
        screenTiles.add(_ParticipantTileData(
          participant: p,
          isLocal: isLocal,
          isHost: isHost,
          handRaised: false,
          name: '$name 的共享',
          avatarUrl: cubit.avatarOf(p),
          videoTrack: screen,
          isScreenShare: true,
        ));
      }
    }

    final local = state.localParticipant;
    if (local != null) {
      collect(local, isLocal: true, isHost: state.isHost, name: '我');
    }
    for (final p in state.remoteParticipants) {
      collect(p,
          isLocal: false,
          isHost: false,
          name: p.name.isNotEmpty ? p.name : p.identity);
    }

    // 有人共享 → 焦点模式：首个共享为大图，其余 + 摄像头为底部缩略图
    if (screenTiles.isNotEmpty) {
      return _FocusStageView(
        focus: screenTiles.first,
        thumbs: [...screenTiles.skip(1), ...cameraTiles],
      );
    }

    return _ParticipantGrid(tiles: cameraTiles);
  }

  /// 取摄像头视频轨（排除屏幕共享；含 source 未知的普通摄像头轨）。
  VideoTrack? _cameraTrackOf(Participant p) {
    for (final pub in p.videoTrackPublications) {
      if (pub.source != TrackSource.screenShareVideo &&
          pub.subscribed &&
          !pub.muted &&
          pub.track != null) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  /// 取屏幕共享视频轨。
  VideoTrack? _screenTrackOf(Participant p) {
    for (final pub in p.videoTrackPublications) {
      if (pub.source == TrackSource.screenShareVideo &&
          pub.subscribed &&
          !pub.muted &&
          pub.track != null) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  Widget _buildConnectingSplash() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          const SizedBox(height: 26),
          Text('正在进入会议室…',
              style: AppTextStyles.body(context)
                  .copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text('请允许摄像头和麦克风权限',
              style:
                  AppTextStyles.caption(context).copyWith(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildControlBar(MeetingState state) {
    final colors = AppColors.of(context);
    final disabled = state.status != MeetingStatus.connected;
    final cubit = context.read<MeetingCubit>();
    final localId = state.localParticipant?.identity;
    final handRaised = localId != null && state.raisedHands.contains(localId);
    // 无发布权限时，麦克风/摄像头/共享按钮锁定置灰，点击提示申请发言。
    final canPublish = state.canPublish;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          decoration: BoxDecoration(
            color: colors.meetingControlBarBg.withValues(alpha: 0.55),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            boxShadow: AppShadows.bottomSheet(context),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                // 主控制：麦克风 / 摄像头 / 挂断（红色放大居中）
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundControl(
                      icon: state.micEnabled ? Icons.mic : Icons.mic_off,
                      label: !canPublish
                          ? '已锁定'
                          : (state.micEnabled ? '静音' : '取消静音'),
                      active: state.micEnabled,
                      dimmed: !canPublish,
                      onTap: disabled
                          ? null
                          : (canPublish
                              ? () => cubit.toggleMic()
                              : _showLockedHint),
                    ),
                    _RoundControl(
                      icon: state.cameraEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      label: !canPublish
                          ? '已锁定'
                          : (state.cameraEnabled ? '关闭画面' : '开启画面'),
                      active: state.cameraEnabled,
                      dimmed: !canPublish,
                      onTap: disabled
                          ? null
                          : (canPublish
                              ? () => cubit.toggleCamera()
                              : _showLockedHint),
                    ),
                    _RoundControl(
                      icon: Icons.call_end,
                      label: '挂断',
                      background: Colors.redAccent,
                      size: 66,
                      onTap: () => _confirmLeave(state),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 次级控制：预留「屏幕共享 / 参会成员 / 聊天 / 举手 / 更多」入口
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SecondaryControl(
                      icon: state.screenSharing
                          ? Icons.stop_screen_share
                          : Icons.screen_share_outlined,
                      label: !canPublish
                          ? '已锁定'
                          : (state.screenSharing ? '停止共享' : '共享'),
                      active: state.screenSharing,
                      dimmed: !canPublish,
                      onTap: disabled
                          ? null
                          : (canPublish
                              ? () => cubit.toggleScreenShare()
                              : _showLockedHint),
                    ),
                    _SecondaryControl(
                      icon: Icons.people_outline,
                      label: '成员',
                      badge: '${state.remoteParticipants.length + 1}',
                      onTap: disabled ? null : _showParticipantsPanel,
                    ),
                    _SecondaryControl(
                      icon: Icons.chat_bubble_outline,
                      label: '聊天',
                      badge: state.messages.isNotEmpty
                          ? '${state.messages.length}'
                          : null,
                      onTap: disabled ? null : _showChatPanel,
                    ),
                    _SecondaryControl(
                      icon: Icons.pan_tool_outlined,
                      label: handRaised ? '放下' : '举手',
                      active: handRaised,
                      onTap: disabled ? null : () => cubit.toggleHand(),
                    ),
                    _SecondaryControl(
                      icon: Icons.more_horiz,
                      label: '更多',
                      onTap: () => _showMoreMenu(state),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<T?> _showGlassBottomSheet<T>({
    required List<Widget> children,
  }) {
    final colors = AppColors.of(context);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colors.meetingGlassBg.withValues(alpha: 0.85),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12))),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ...children,
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback? onTap,
  }) {
    // 用 Material + InkWell 替代 ListTile：玻璃面板（BackdropFilter）非不透明 Material，
    // ListTile 会触发「background color or ink splashes may be invisible」警告。
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? Colors.white, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: titleColor ?? Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(MeetingState state) {
    final cubit = context.read<MeetingCubit>();
    final disabled = state.status != MeetingStatus.connected;
    _showGlassBottomSheet<void>(
      children: [
        if (state.isHost)
          _sheetTile(
            icon: Icons.drive_file_rename_outline,
            title: '修改主题',
            subtitle: state.title ?? '未命名会议',
            onTap: disabled
                ? null
                : () {
                    Navigator.pop(context);
                    _showRenameDialog(state);
                  },
          ),
        _sheetTile(
          icon: Icons.cameraswitch,
          title: '翻转摄像头',
          subtitle: '切换前/后置',
          onTap: disabled
              ? null
              : () {
                  Navigator.pop(context);
                  cubit.switchCamera();
                },
        ),
        _sheetTile(
          icon: state.speakerOn ? Icons.volume_up : Icons.hearing,
          title: state.speakerOn ? '切换为听筒' : '切换为扬声器',
          subtitle: state.speakerOn ? '当前：扬声器' : '当前：听筒',
          onTap: disabled
              ? null
              : () {
                  Navigator.pop(context);
                  cubit.toggleSpeaker();
                },
        ),
        _sheetTile(
          icon: Icons.copy,
          title: '复制会议号',
          subtitle: state.roomName ?? '',
          onTap: () {
            if (state.roomName != null) {
              Clipboard.setData(ClipboardData(text: state.roomName!));
              BdxToast.show(
                context,
                message: '会议号已复制',
                icon: Icons.copy,
              );
            }
            Navigator.pop(context);
          },
        ),
        _sheetTile(
          icon: Icons.info_outline,
          title: '会议信息',
          subtitle: '查看会议详情',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(MeetingState state) async {
    final cubit = context.read<MeetingCubit>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(
        initialTitle: state.title,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await cubit.renameTitle(result);
      if (mounted) {
        BdxToast.show(
          context,
          message: '会议主题已更新',
          icon: Icons.check_circle_outline,
        );
      }
    } catch (_) {
      if (mounted) {
        BdxToast.show(
          context,
          message: '主题已本地更新，服务端同步失败',
          icon: Icons.error_outline,
        );
      }
    }
  }
}

// ===== 头部信息小胶囊 =====
class _PillBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.captionSmall(context)
                  .copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

// ===== 连接中脉冲圆 =====
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final scale = 1.0 + t * 0.08;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10 + t * 0.05),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary
                      .withValues(alpha: 0.20 + t * 0.15),
                  blurRadius: 30 + t * 10,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.primaryLight,
                  strokeWidth: 3,
                  value: 0.35 + t * 0.3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ParticipantTileData {
  final Participant participant;
  final bool isLocal;
  final bool isHost;
  final bool handRaised;
  final String name;
  final String? avatarUrl;

  /// 该格要渲染的视频轨（摄像头或屏幕共享）；为空则显示头像占位。
  final VideoTrack? videoTrack;

  /// 是否为屏幕共享格（影响填充方式与角标）。
  final bool isScreenShare;

  _ParticipantTileData({
    required this.participant,
    required this.isLocal,
    required this.isHost,
    required this.handRaised,
    required this.name,
    this.avatarUrl,
    this.videoTrack,
    this.isScreenShare = false,
  });
}

/// 参与者网格：自适应人数。
///
/// 1 人满屏；2~4 人两列；5~9 人三列；10+ 人按屏幕宽度动态列数（2~4）并支持滚动，
/// 保证单格不小于 [_minTileWidth]，应对后续大人数场景。
class _ParticipantGrid extends StatelessWidget {
  final List<_ParticipantTileData> tiles;
  static const double _minTileWidth = 130;

  const _ParticipantGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = tiles.length;
        int crossAxisCount;
        double ratio;

        if (count == 1) {
          crossAxisCount = 1;
          ratio = constraints.maxWidth / constraints.maxHeight;
        } else {
          final byWidth =
              (constraints.maxWidth / _minTileWidth).floor().clamp(2, 4);
          if (count <= 4) {
            crossAxisCount = 2;
          } else if (count <= 9) {
            crossAxisCount = 3;
          } else {
            crossAxisCount = byWidth;
          }
          ratio = 0.82;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          physics: count > 9
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: ratio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) =>
              _ParticipantTile(data: tiles[index]),
        );
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final _ParticipantTileData data;

  const _ParticipantTile({required this.data});

  void _openFullscreen(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: true,
      barrierLabel: '关闭',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => _FullscreenVideoView(data: data),
    );
  }

  Color get _avatarColor {
    final colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.pink,
      AppColors.success,
    ];
    return colors[data.name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final track = data.videoTrack;
    final hasVideo = track != null;
    final isSpeaking = data.participant.isSpeaking;
    final isMuted = data.participant.isMuted;

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colors.meetingCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSpeaking ? AppColors.success : Colors.white10,
            width: isSpeaking ? 2.5 : 1,
          ),
          boxShadow: isSpeaking
              ? [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: hasVideo
                  ? VideoTrackRenderer(
                      track,
                      key: ValueKey('video-${track.sid}'),
                      fit: data.isScreenShare
                          ? VideoViewFit.contain
                          : VideoViewFit.cover,
                    )
                  : _AvatarPlaceholder(
                      key: const ValueKey('avatar'),
                      color: _avatarColor,
                      name: data.name,
                      avatarUrl: data.avatarUrl,
                    ),
            ),
            // 左上角：屏幕共享标记
            if (data.isScreenShare)
              Positioned(
                top: 8,
                left: 8,
                child: _CornerBadge(
                  color: AppColors.primaryLight,
                  icon: Icons.screen_share,
                ),
              ),
            // 右上角：举手 / 主持人徽标
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.isHost)
                    _CornerBadge(
                      color: AppColors.accent,
                      icon: Icons.workspace_premium,
                    ),
                  if (data.handRaised) ...[
                    const SizedBox(width: 4),
                    _HandRaisedBadge(),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMuted)
                      const Icon(Icons.mic_off,
                          size: 12, color: Colors.redAccent)
                    else
                      _AudioBars(active: isSpeaking),
                    const SizedBox(width: 6),
                    Text(
                      data.name,
                      style: AppTextStyles.label(context)
                          .copyWith(color: Colors.white),
                    ),
                    if (data.isLocal) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 无视频时的头像占位：双层光晕 + 渐变描边头像。
class _AvatarPlaceholder extends StatelessWidget {
  final Color color;
  final String name;
  final String? avatarUrl;

  const _AvatarPlaceholder({
    super.key,
    required this.color,
    required this.name,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = AppColors.of(context);
        final side = constraints.biggest.shortestSide;
        final avatarRadius = side * 0.22;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.meetingCardBg,
                color.withValues(alpha: 0.28),
              ],
            ),
          ),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.avatarGlow(color, opacity: 0.4),
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.6)],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: avatarRadius - 2,
                    backgroundColor: colors.meetingCardBg,
                    child: ParticipantAvatar(
                      name: name,
                      avatarUrl: avatarUrl,
                      size: (avatarRadius - 2) * 2,
                      textStyle: AppTextStyles.headline(context)
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CornerBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _CornerBadge({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

class _HandRaisedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: const Icon(Icons.pan_tool, size: 12, color: AppColors.accent),
    );
  }
}

// ===== 音频动态条 =====
class _AudioBars extends StatefulWidget {
  final bool active;
  const _AudioBars({required this.active});

  @override
  State<_AudioBars> createState() => _AudioBarsState();
}

class _AudioBarsState extends State<_AudioBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _bar(0.35 + (widget.active ? sin(t * pi * 2) * 0.35 : 0)),
            const SizedBox(width: 2),
            _bar(0.55 + (widget.active ? cos(t * pi * 2.3) * 0.4 : 0)),
            const SizedBox(width: 2),
            _bar(0.4 + (widget.active ? sin(t * pi * 1.7 + 1) * 0.35 : 0)),
          ],
        );
      },
    );
  }

  Widget _bar(double heightFactor) {
    final h = 4 + (heightFactor.clamp(0.0, 1.0) * 7);
    return Container(
      width: 2.5,
      height: h,
      decoration: BoxDecoration(
        color: widget.active ? AppColors.success : Colors.white70,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

// ===== 主控制按钮（圆形） =====
class _RoundControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? background;
  final double size;
  final VoidCallback? onTap;

  /// 置灰但仍可点击（用于「无权限」锁定态，点击给出提示）。
  final bool dimmed;

  const _RoundControl({
    required this.icon,
    required this.label,
    this.active = true,
    this.background,
    this.size = 58,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ??
        (active ? AppColors.primary : Colors.white.withValues(alpha: 0.12));
    return PressScale(
      onTap: onTap,
      child: Opacity(
        opacity: (onTap == null || dimmed) ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: active && background == null
                    ? AppShadows.avatarGlow(AppColors.primary, opacity: 0.35)
                    : background != null
                        ? AppShadows.avatarGlow(background!, opacity: 0.4)
                        : null,
              ),
              child: Icon(icon, color: Colors.white, size: size * 0.45),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: AppTextStyles.caption(context)
                    .copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ===== 次级控制按钮（图标 + 文字，可带角标/激活态） =====
class _SecondaryControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String? badge;
  final VoidCallback? onTap;

  /// 置灰但仍可点击（用于「无权限」锁定态，点击给出提示）。
  final bool dimmed;

  const _SecondaryControl({
    required this.icon,
    required this.label,
    this.active = false,
    this.badge,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PressScale(
      onTap: onTap,
      child: Opacity(
        opacity: (onTap == null || dimmed) ? 0.4 : 1,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.accent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? AppColors.accent.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: active ? AppColors.accent : Colors.white70,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: colors.meetingControlBarBg, width: 1.5),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.captionSmall(context)
                    .copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 修改会议主题对话框 =====
class _RenameDialog extends StatefulWidget {
  final String? initialTitle;

  const _RenameDialog({
    required this.initialTitle,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _focused = false;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle ?? '');
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _onChanged();
    });
  }

  void _onChanged() {
    final v = _controller.text.trim();
    final can = v.isNotEmpty && v != (widget.initialTitle ?? '');
    if (can != _canSubmit) setState(() => _canSubmit = can);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            decoration: BoxDecoration(
              color: colors.meetingGlassBg.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('修改会议主题',
                    style: AppTextStyles.title(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text('仅主持人可修改，所有人将看到新主题',
                    style: AppTextStyles.caption(context)
                        .copyWith(color: Colors.white54)),
                const SizedBox(height: 18),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _focused
                          ? AppColors.primaryLight.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.14),
                      width: _focused ? 1.6 : 1.2,
                    ),
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                              color: AppColors.primaryGlow
                                  .withValues(alpha: 0.28),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.06),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        cursorColor: Colors.white,
                        textInputAction: TextInputAction.done,
                        maxLength: 40,
                        onTapOutside: (_) => _focusNode.unfocus(),
                        decoration: const InputDecoration(
                          hintText: '输入新的会议主题',
                          hintStyle:
                              TextStyle(color: Colors.white54, fontSize: 15),
                          counterStyle:
                              TextStyle(color: Colors.white38, fontSize: 11),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: PressScale(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text('取消',
                              style: AppTextStyles.body(context)
                                  .copyWith(color: Colors.white70)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PressScale(
                        onTap: _canSubmit ? _submit : null,
                        child: Opacity(
                          opacity: _canSubmit ? 1 : 0.4,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.glowPrimary(opacity: 0.35),
                            ),
                            child: Text('保存',
                                style: AppTextStyles.body(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    Navigator.pop(context, v);
  }
}

// ===== 焦点视图：屏幕共享大图 + 底部缩略图条 =====
class _FocusStageView extends StatelessWidget {
  final _ParticipantTileData focus;
  final List<_ParticipantTileData> thumbs;

  const _FocusStageView({required this.focus, required this.thumbs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: _ParticipantTile(data: focus),
          ),
        ),
        if (thumbs.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              itemCount: thumbs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => AspectRatio(
                aspectRatio: 0.82,
                child: _ParticipantTile(data: thumbs[i]),
              ),
            ),
          ),
      ],
    );
  }
}

// ===== 全屏查看单个画面（点击空白或关闭按钮退出）=====
class _FullscreenVideoView extends StatelessWidget {
  final _ParticipantTileData data;

  const _FullscreenVideoView({required this.data});

  Color get _avatarColor {
    final colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.pink,
      AppColors.success,
    ];
    return colors[data.name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final track = data.videoTrack;
    // 用 SizedBox.expand 兜底铺满整屏，避免内容被挤到顶部裁切。
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: track != null
                  ? VideoTrackRenderer(track, fit: VideoViewFit.contain)
                  : _buildAvatarHero(context),
            ),
            // 顶部渐变遮罩 + 名字 + 关闭按钮
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        PressScale(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 无视频时的居中头像大图。
  Widget _buildAvatarHero(BuildContext context) {
    final color = _avatarColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.55)],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 32,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ParticipantAvatar(
              name: data.name,
              avatarUrl: data.avatarUrl,
              size: 132,
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off,
                  size: 15, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                '摄像头未开启',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== 离开 / 结束会议 Loading 遮罩 =====
class _LeavingOverlay extends StatelessWidget {
  final String label;

  const _LeavingOverlay({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: colors.meetingGlassBg.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLight,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style:
                      AppTextStyles.body(context).copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== 会议时长标签（独立计时，避免重建整个页面）=====
class _MeetingDurationBadge extends StatefulWidget {
  final bool isRunning;

  const _MeetingDurationBadge({required this.isRunning});

  @override
  State<_MeetingDurationBadge> createState() => _MeetingDurationBadgeState();
}

class _MeetingDurationBadgeState extends State<_MeetingDurationBadge> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isRunning) _start();
  }

  @override
  void didUpdateWidget(covariant _MeetingDurationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !oldWidget.isRunning) {
      _start();
    } else if (!widget.isRunning && oldWidget.isRunning) {
      _stop();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _elapsedSeconds = 0;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _PillBadge(
      icon: Icons.timer_outlined,
      label: _formatDuration(_elapsedSeconds),
    );
  }
}
