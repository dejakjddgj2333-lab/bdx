import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart';

enum MeetingStatus { initial, connecting, connected, disconnected, error }

class MeetingState extends Equatable {
  final MeetingStatus status;
  final String? roomName;
  final String? title;
  final bool isHost;
  final bool micEnabled;
  final bool cameraEnabled;
  final bool speakerOn;
  final LocalParticipant? localParticipant;
  final List<RemoteParticipant> remoteParticipants;
  final String? errorMessage;
  // 用于触发 UI 刷新（参与者轨道变化时自增）
  final int revision;

  const MeetingState({
    this.status = MeetingStatus.initial,
    this.roomName,
    this.title,
    this.isHost = false,
    this.micEnabled = true,
    this.cameraEnabled = true,
    this.speakerOn = true,
    this.localParticipant,
    this.remoteParticipants = const [],
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
    LocalParticipant? localParticipant,
    List<RemoteParticipant>? remoteParticipants,
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
      localParticipant: localParticipant ?? this.localParticipant,
      remoteParticipants: remoteParticipants ?? this.remoteParticipants,
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
        localParticipant,
        remoteParticipants,
        errorMessage,
        revision,
      ];
}
