import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';

enum MeetingStatus { initial, connecting, connected, disconnected, error }

/// 会议内临时聊天消息（仅本次会议有效，不落库）。
class MeetingChatMessage extends Equatable {
  final String senderIdentity;
  final String senderName;

  /// 发送者头像 URL（可为相对路径，渲染时补全为完整地址）；为空时回退首字母头像。
  final String? senderAvatar;
  final String text;
  final DateTime sentAt;
  final bool isLocal;

  const MeetingChatMessage({
    required this.senderIdentity,
    required this.senderName,
    this.senderAvatar,
    required this.text,
    required this.sentAt,
    this.isLocal = false,
  });

  @override
  List<Object?> get props =>
      [senderIdentity, senderName, senderAvatar, text, sentAt, isLocal];
}

class MeetingState extends Equatable {
  final MeetingStatus status;
  final String? roomName;
  final String? title;
  final bool isHost;
  final bool micEnabled;
  final bool cameraEnabled;
  final bool speakerOn;
  final bool screenSharing;

  /// 本地用户是否有发布权限（说话/视频/屏幕共享）。
  /// 默认 false：除主持人外，需主持人授予后方可开启。
  final bool canPublish;
  final LocalParticipant? localParticipant;
  final List<RemoteParticipant> remoteParticipants;

  /// 已举手成员的 LiveKit identity 集合（含本地用户）。
  final Set<String> raisedHands;

  /// 会议内临时聊天记录（按时间顺序）。
  final List<MeetingChatMessage> messages;

  final String? errorMessage;
  // 用于触发 UI 刷新（参与者轨道变化时自增）
  final int revision;

  const MeetingState({
    this.status = MeetingStatus.initial,
    this.roomName,
    this.title,
    this.isHost = false,
    this.micEnabled = true,
    this.cameraEnabled = false,
    this.speakerOn = true,
    this.screenSharing = false,
    this.canPublish = false,
    this.localParticipant,
    this.remoteParticipants = const [],
    this.raisedHands = const {},
    this.messages = const [],
    this.errorMessage,
    this.revision = 0,
  });

  MeetingState copyWith({
    MeetingStatus? status,
    String? roomName,
    String? title,
    bool? isHost,
    bool? micEnabled,
    bool? cameraEnabled,
    bool? speakerOn,
    bool? screenSharing,
    bool? canPublish,
    LocalParticipant? localParticipant,
    List<RemoteParticipant>? remoteParticipants,
    Set<String>? raisedHands,
    List<MeetingChatMessage>? messages,
    String? errorMessage,
    int? revision,
  }) {
    return MeetingState(
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      title: title ?? this.title,
      isHost: isHost ?? this.isHost,
      micEnabled: micEnabled ?? this.micEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      speakerOn: speakerOn ?? this.speakerOn,
      screenSharing: screenSharing ?? this.screenSharing,
      canPublish: canPublish ?? this.canPublish,
      localParticipant: localParticipant ?? this.localParticipant,
      remoteParticipants: remoteParticipants ?? this.remoteParticipants,
      raisedHands: raisedHands ?? this.raisedHands,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props => [
        status,
        roomName,
        title,
        isHost,
        micEnabled,
        cameraEnabled,
        speakerOn,
        screenSharing,
        canPublish,
        localParticipant,
        remoteParticipants,
        raisedHands,
        messages,
        errorMessage,
        revision,
      ];
}
