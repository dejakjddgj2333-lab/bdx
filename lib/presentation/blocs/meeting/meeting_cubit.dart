import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/datasources/remote/meeting_api.dart';
import 'meeting_state.dart';

class MeetingCubit extends Cubit<MeetingState> {
  final MeetingApi _meetingApi;

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  CameraPosition _cameraPosition = CameraPosition.front;

  MeetingCubit(this._meetingApi) : super(const MeetingState());

  Room? get room => _room;

  /// 创建新会议并加入
  Future<void> createAndJoin({String? title}) async {
    try {
      final res = await _meetingApi.createMeeting(title: title);
      final data = res.data['data'] as Map<String, dynamic>;
      await join(data['room_name'] as String);
    } catch (e) {
      emit(state.copyWith(
        status: MeetingStatus.error,
        errorMessage: '创建会议失败：$e',
      ));
    }
  }

  /// 加入已有会议
  Future<void> join(String roomName) async {
    emit(state.copyWith(status: MeetingStatus.connecting, roomName: roomName));

    // 申请权限
    final granted = await _ensurePermissions();
    if (!granted) {
      emit(state.copyWith(
        status: MeetingStatus.error,
        errorMessage: '需要摄像头和麦克风权限',
      ));
      return;
    }

    try {
      final res = await _meetingApi.joinMeeting(roomName);
      final data = res.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final url = data['url'] as String;
      final isHost = data['is_host'] == true;

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _listener = room.createListener();
      _bindEvents(room);

      await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(state.micEnabled);
      await room.localParticipant?.setCameraEnabled(state.cameraEnabled);

      _room = room;
      emit(state.copyWith(
        status: MeetingStatus.connected,
        roomName: roomName,
        isHost: isHost,
        localParticipant: room.localParticipant,
        remoteParticipants: room.remoteParticipants.values.toList(),
        revision: state.revision + 1,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MeetingStatus.error,
        errorMessage: '加入会议失败：$e',
      ));
    }
  }

  void _bindEvents(Room room) {
    _listener
      ?..on<ParticipantConnectedEvent>((_) => _refreshParticipants(room))
      ..on<ParticipantDisconnectedEvent>((_) => _refreshParticipants(room))
      ..on<TrackSubscribedEvent>((_) => _refreshParticipants(room))
      ..on<TrackUnsubscribedEvent>((_) => _refreshParticipants(room))
      ..on<TrackMutedEvent>((_) => _refreshParticipants(room))
      ..on<TrackUnmutedEvent>((_) => _refreshParticipants(room))
      ..on<LocalTrackPublishedEvent>((_) => _refreshParticipants(room))
      ..on<LocalTrackUnpublishedEvent>((_) => _refreshParticipants(room))
      ..on<RoomDisconnectedEvent>((_) {
        emit(state.copyWith(status: MeetingStatus.disconnected));
      });
  }

  void _refreshParticipants(Room room) {
    if (isClosed) return;
    emit(state.copyWith(
      remoteParticipants: room.remoteParticipants.values.toList(),
      localParticipant: room.localParticipant,
      revision: state.revision + 1,
    ));
  }

  Future<void> toggleMic() async {
    final next = !state.micEnabled;
    await _room?.localParticipant?.setMicrophoneEnabled(next);
    emit(state.copyWith(micEnabled: next, revision: state.revision + 1));
  }

  Future<void> toggleCamera() async {
    final next = !state.cameraEnabled;
    await _room?.localParticipant?.setCameraEnabled(next);
    emit(state.copyWith(cameraEnabled: next, revision: state.revision + 1));
  }

  Future<void> switchCamera() async {
    final track = _room?.localParticipant?.videoTrackPublications
        .firstOrNull?.track;
    if (track is LocalVideoTrack) {
      _cameraPosition = _cameraPosition.switched();
      await track.setCameraPosition(_cameraPosition);
    }
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    try {
      await Hardware.instance.setSpeakerphoneOn(next);
    } catch (_) {}
    emit(state.copyWith(speakerOn: next));
  }

  /// 离开会议（不结束房间）
  Future<void> leave() async {
    await _listener?.dispose();
    await _room?.disconnect();
    await _room?.dispose();
    _listener = null;
    _room = null;
    emit(state.copyWith(status: MeetingStatus.disconnected));
  }

  /// 结束会议（仅主持人，销毁房间）
  Future<void> endMeeting() async {
    final roomName = state.roomName;
    if (roomName != null) {
      try {
        await _meetingApi.endMeeting(roomName);
      } catch (_) {}
    }
    await leave();
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  @override
  Future<void> close() async {
    await _listener?.dispose();
    await _room?.dispose();
    return super.close();
  }
}
