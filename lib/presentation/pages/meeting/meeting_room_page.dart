import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/constants/app_colors.dart';
import '../../blocs/meeting/meeting_cubit.dart';
import '../../blocs/meeting/meeting_state.dart';

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

  Future<void> _confirmLeave(MeetingState state) async {
    final cubit = context.read<MeetingCubit>();
    if (state.isHost) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1A1530),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text('离开会议',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('会议继续，其他人不受影响',
                    style: TextStyle(color: Colors.white54)),
                onTap: () => Navigator.pop(ctx, 'leave'),
              ),
              ListTile(
                leading: const Icon(Icons.call_end, color: Colors.redAccent),
                title: const Text('结束会议',
                    style: TextStyle(color: Colors.redAccent)),
                subtitle: const Text('所有人将被移出',
                    style: TextStyle(color: Colors.white54)),
                onTap: () => Navigator.pop(ctx, 'end'),
              ),
            ],
          ),
        ),
      );
      if (choice == 'leave') {
        await cubit.leave();
        if (mounted) context.pop();
      } else if (choice == 'end') {
        await cubit.endMeeting();
        if (mounted) context.pop();
      }
    } else {
      await cubit.leave();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MeetingCubit, MeetingState>(
      listener: (context, state) {
        if (state.status == MeetingStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? '会议出错')),
          );
        }
        if (state.status == MeetingStatus.disconnected &&
            state.errorMessage == null) {
          // 房间被结束等情况，自动返回
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) _confirmLeave(state);
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0814),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(state),
                  Expanded(child: _buildBody(state)),
                  _buildControlBar(state),
                ],
              ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title ?? '会议',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                if (state.roomName != null)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: state.roomName!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('会议号已复制')),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('会议号：${state.roomName}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy,
                            size: 12, color: Colors.white54),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text('$count',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MeetingState state) {
    if (state.status == MeetingStatus.connecting ||
        state.status == MeetingStatus.initial) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('正在连接…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    final tiles = <_ParticipantTileData>[];
    final local = state.localParticipant;
    if (local != null) {
      tiles.add(_ParticipantTileData(
        participant: local,
        isLocal: true,
        name: '我',
      ));
    }
    for (final p in state.remoteParticipants) {
      tiles.add(_ParticipantTileData(
        participant: p,
        isLocal: false,
        name: p.name.isNotEmpty ? p.name : p.identity,
      ));
    }

    final crossAxisCount = tiles.length <= 1 ? 1 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: tiles.length <= 1 ? 0.7 : 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) => _ParticipantTile(data: tiles[index]),
    );
  }

  Widget _buildControlBar(MeetingState state) {
    final disabled = state.status != MeetingStatus.connected;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(color: Color(0xFF141022)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ControlButton(
            icon: state.micEnabled ? Icons.mic : Icons.mic_off,
            label: state.micEnabled ? '静音' : '取消静音',
            active: state.micEnabled,
            onTap: disabled
                ? null
                : () => context.read<MeetingCubit>().toggleMic(),
          ),
          _ControlButton(
            icon: state.cameraEnabled
                ? Icons.videocam
                : Icons.videocam_off,
            label: state.cameraEnabled ? '关摄像头' : '开摄像头',
            active: state.cameraEnabled,
            onTap: disabled
                ? null
                : () => context.read<MeetingCubit>().toggleCamera(),
          ),
          _ControlButton(
            icon: Icons.cameraswitch,
            label: '翻转',
            active: true,
            onTap: disabled
                ? null
                : () => context.read<MeetingCubit>().switchCamera(),
          ),
          _ControlButton(
            icon: state.speakerOn ? Icons.volume_up : Icons.hearing,
            label: state.speakerOn ? '扬声器' : '听筒',
            active: state.speakerOn,
            onTap: disabled
                ? null
                : () => context.read<MeetingCubit>().toggleSpeaker(),
          ),
          _ControlButton(
            icon: Icons.call_end,
            label: '挂断',
            active: true,
            background: Colors.redAccent,
            onTap: () => _confirmLeave(state),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTileData {
  final Participant participant;
  final bool isLocal;
  final String name;

  _ParticipantTileData({
    required this.participant,
    required this.isLocal,
    required this.name,
  });
}

class _ParticipantTile extends StatelessWidget {
  final _ParticipantTileData data;

  const _ParticipantTile({required this.data});

  VideoTrack? get _videoTrack {
    for (final pub in data.participant.videoTrackPublications) {
      if (pub.subscribed && !pub.muted && pub.track != null) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final track = _videoTrack;
    final hasVideo = track != null;
    final isSpeaking = data.participant.isSpeaking;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1730),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSpeaking ? AppColors.primaryLight : Colors.white10,
          width: isSpeaking ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo)
            VideoTrackRenderer(track)
          else
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary,
                child: Text(
                  data.name.isNotEmpty
                      ? data.name.characters.first.toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26),
                ),
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    data.participant.isMuted ? Icons.mic_off : Icons.mic,
                    size: 12,
                    color: data.participant.isMuted
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? background;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ??
        (active ? AppColors.primary : Colors.white.withOpacity(0.12));
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
