import 'dart:convert';

import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
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

  /// 本地用户的 LiveKit identity（= 后端签发的用户ID字符串）。
  String? get localIdentity => state.localParticipant?.identity;

  /// 从参与者 metadata 中解析头像 URL（后端入会时写入）。
  String? _avatarOf(Participant? p) {
    final meta = p?.metadata;
    if (meta == null || meta.isEmpty) return null;
    try {
      final json = jsonDecode(meta) as Map<String, dynamic>;
      final a = json['avatar'];
      return (a is String && a.isNotEmpty) ? a : null;
    } catch (_) {
      return null;
    }
  }

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
        errorMessage: '需要麦克风权限才能加入会议',
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

      // 权限控制：默认仅主持人可发布。非主持人入会时 canPublish=false，
      // 不尝试开启音视频，等待主持人授权后再手动开启。
      final canPublish =
          isHost || (room.localParticipant?.permissions.canPublish ?? false);

      if (canPublish) {
        // 开启本地音视频。模拟器无音视频采集硬件，getUserMedia 会失败，
        // 这里单独容错，不阻断入会（真机正常采集）。
        try {
          await room.localParticipant?.setMicrophoneEnabled(state.micEnabled);
        } catch (e) {
          emit(state.copyWith(micEnabled: false));
        }
        try {
          await room.localParticipant?.setCameraEnabled(state.cameraEnabled);
        } catch (e) {
          emit(state.copyWith(cameraEnabled: false));
        }
      }

      _room = room;
      emit(state.copyWith(
        status: MeetingStatus.connected,
        roomName: roomName,
        isHost: isHost,
        canPublish: canPublish,
        micEnabled: canPublish ? state.micEnabled : false,
        cameraEnabled: canPublish ? state.cameraEnabled : false,
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
      ..on<DataReceivedEvent>((e) => _onData(e))
      ..on<ParticipantPermissionsUpdatedEvent>(
          (e) => _onPermissionsUpdated(e))
      ..on<RoomDisconnectedEvent>((_) {
        emit(state.copyWith(status: MeetingStatus.disconnected));
      });
  }

  /// 权限变更：被授予/收回发布权限时同步本地状态。
  /// - 本地用户：更新 canPublish；被收回时 LiveKit 已自动取消其轨道，
  ///   这里把麦克风/摄像头/共享标记一并复位。
  /// - 远端成员：刷新参与者列表，让主持人面板实时反映其权限。
  void _onPermissionsUpdated(ParticipantPermissionsUpdatedEvent e) {
    if (isClosed) return;
    final room = _room;
    if (room == null) return;
    final localId = room.localParticipant?.identity;
    if (e.participant.identity == localId) {
      final canPublish = state.isHost || e.permissions.canPublish;
      if (canPublish) {
        emit(state.copyWith(canPublish: true, revision: state.revision + 1));
      } else {
        emit(state.copyWith(
          canPublish: false,
          micEnabled: false,
          cameraEnabled: false,
          screenSharing: false,
          revision: state.revision + 1,
        ));
      }
    } else {
      _refreshParticipants(room);
    }
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
    if (!state.canPublish) return; // 无发布权限：交由 UI 提示，静默拦截
    final next = !state.micEnabled;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(next);
    } catch (e) {
      emit(state.copyWith(
        status: MeetingStatus.error,
        errorMessage: '麦克风开启失败：$e',
      ));
      return;
    }
    emit(state.copyWith(micEnabled: next, revision: state.revision + 1));
  }

  Future<void> toggleCamera() async {
    if (!state.canPublish) return; // 无发布权限：交由 UI 提示，静默拦截
    final next = !state.cameraEnabled;
    try {
      await _room?.localParticipant?.setCameraEnabled(next);
    } catch (e) {
      emit(state.copyWith(
        status: MeetingStatus.error,
        errorMessage: '摄像头开启失败：$e',
      ));
      return;
    }
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

  /// 屏幕共享开关。
  ///
  /// Android：先请求录屏权限，再启动 media projection 前台服务（flutter_background），
  /// 才能 publish 屏幕轨道；关闭时停止前台服务。
  /// iOS：已配置 Broadcast Upload Extension（ios/BroadcastExtension）。
  /// setScreenShareEnabled(true) 会自动弹出系统录屏选择器（RPSystemBroadcastPickerView），
  /// 用户选定后由扩展采集屏幕、经 App Group socket 发布屏幕轨道，无需额外处理。
  /// 模拟器无采集源会失败——统一 try/catch 不阻断会议。
  Future<void> toggleScreenShare() async {
    if (!state.canPublish) return; // 无发布权限：交由 UI 提示，静默拦截
    final lp = _room?.localParticipant;
    if (lp == null) return;
    final next = !state.screenSharing;
    try {
      if (next) {
        if (lkPlatformIs(PlatformType.android)) {
          final granted = await Helper.requestCapturePermission();
          if (!granted) {
            // 用户拒绝录屏授权，给出明确提示
            emit(state.copyWith(
              status: MeetingStatus.error,
              errorMessage: '需要允许屏幕录制权限才能共享屏幕',
            ));
            return;
          }
          final serviceReady = await _enableAndroidScreenShareService();
          if (!serviceReady) {
            emit(state.copyWith(
              status: MeetingStatus.error,
              errorMessage: '屏幕共享前台服务启动失败，请确保已授予通知权限',
            ));
            return;
          }
        }
        await lp.setScreenShareEnabled(true);
      } else {
        await lp.setScreenShareEnabled(false);
        if (lkPlatformIs(PlatformType.android)) {
          try {
            await FlutterBackground.disableBackgroundExecution();
          } catch (_) {}
        }
      }
      emit(state.copyWith(screenSharing: next, revision: state.revision + 1));
    } catch (e) {
      // 失败时尽量回收前台服务，避免常驻通知
      if (next && lkPlatformIs(PlatformType.android)) {
        try {
          await FlutterBackground.disableBackgroundExecution();
        } catch (_) {}
      }
      emit(state.copyWith(
        status: MeetingStatus.error,
        errorMessage: next ? '无法开启屏幕共享：$e' : '停止屏幕共享失败：$e',
      ));
    }
  }

  /// 启动 Android media projection 前台服务（屏幕共享前置条件）。
  ///
  /// 返回 true 表示服务已成功进入前台状态；false 表示初始化失败（通常是
  /// Android 13+ 未授予通知权限）或服务未能及时进入前台。
  Future<bool> _enableAndroidScreenShareService() async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: '屏幕共享中',
      notificationText: '正在向会议共享你的屏幕',
      notificationImportance: AndroidNotificationImportance.normal,
      notificationIcon:
          AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    final hasPermissions =
        await FlutterBackground.initialize(androidConfig: androidConfig);
    if (!hasPermissions) return false;

    if (!FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.enableBackgroundExecution();
    }

    // Android 14+ 要求调用 getDisplayMedia 时前台服务必须已处于活跃状态。
    // startForegroundService 是异步的，返回时服务未必真正进入前台，因此
    // 轮询等待而不是依赖固定延迟。
    var retries = 0;
    const maxRetries = 50; // 最多等待 5 秒
    while (!FlutterBackground.isBackgroundExecutionEnabled && retries < maxRetries) {
      if (isClosed) return false;
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
    return FlutterBackground.isBackgroundExecutionEnabled;
  }

  // ===== DataChannel：聊天 / 举手 / 主题实时同步 =====

  /// 广播一条 JSON 数据消息给房间内所有人。
  Future<void> _publishData(Map<String, dynamic> payload) async {
    final lp = _room?.localParticipant;
    if (lp == null) return;
    try {
      await lp.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
      );
    } catch (_) {
      // 发送失败（如连接中断）静默忽略，不影响本地状态
    }
  }

  /// 收到远端数据消息：按 type 分发。
  void _onData(DataReceivedEvent event) {
    if (isClosed) return;
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (payload['type']) {
      case 'hand':
        _applyHandEvent(payload);
        break;
      case 'chat':
        final from = event.participant;
        emit(state.copyWith(
          messages: [
            ...state.messages,
            MeetingChatMessage(
              senderIdentity: from?.identity ?? '',
              senderName: (payload['name'] as String?)?.trim().isNotEmpty == true
                  ? payload['name'] as String
                  : (from?.name.isNotEmpty == true ? from!.name : '匿名'),
              senderAvatar: (payload['avatar'] as String?)?.isNotEmpty == true
                  ? payload['avatar'] as String
                  : _avatarOf(from),
              text: payload['text'] as String? ?? '',
              sentAt: DateTime.now(),
              isLocal: false,
            ),
          ],
          revision: state.revision + 1,
        ));
        break;
      case 'topic':
        final title = (payload['title'] as String?)?.trim();
        if (title != null && title.isNotEmpty && title != state.title) {
          emit(state.copyWith(title: title, revision: state.revision + 1));
        }
        break;
    }
  }

  void _applyHandEvent(Map<String, dynamic> payload) {
    final hands = Set<String>.from(state.raisedHands);
    switch (payload['action']) {
      case 'raise':
        final id = payload['identity'] as String?;
        if (id != null) hands.add(id);
        break;
      case 'lower':
        final id = payload['identity'] as String?;
        if (id != null) hands.remove(id);
        break;
      case 'force_lower':
        final target = payload['target'] as String?;
        if (target != null && target.isNotEmpty) {
          hands.remove(target);
        } else {
          hands.clear();
        }
        break;
    }
    emit(state.copyWith(raisedHands: hands, revision: state.revision + 1));
  }

  /// 举手 / 放下（本地用户），并广播给其他成员。
  Future<void> toggleHand() async {
    final id = localIdentity;
    if (id == null) return;
    final hands = Set<String>.from(state.raisedHands);
    final raising = !hands.contains(id);
    if (raising) {
      hands.add(id);
    } else {
      hands.remove(id);
    }
    emit(state.copyWith(raisedHands: hands, revision: state.revision + 1));
    await _publishData({
      'type': 'hand',
      'action': raising ? 'raise' : 'lower',
      'identity': id,
    });
  }

  /// 主持人放下指定成员的手；[identity] 为空表示放下全体。
  Future<void> lowerHandFor(String? identity) async {
    if (!state.isHost) return;
    final hands = Set<String>.from(state.raisedHands);
    if (identity != null && identity.isNotEmpty) {
      hands.remove(identity);
    } else {
      hands.clear();
    }
    emit(state.copyWith(raisedHands: hands, revision: state.revision + 1));
    await _publishData({
      'type': 'hand',
      'action': 'force_lower',
      'target': identity ?? '',
    });
  }

  /// 主持人授予/收回某成员的发布权限（说话/视频/屏幕共享）。
  /// 通过服务端调用 LiveKit updateParticipant，权限变更由 LiveKit
  /// 推送给目标成员（其 [ParticipantPermissionsUpdatedEvent] 会更新本地状态）。
  Future<void> setPublishPermission(String identity, bool canPublish) async {
    if (!state.isHost) return;
    final roomName = state.roomName;
    if (roomName == null || identity.isEmpty) return;
    try {
      await _meetingApi.setParticipantPermission(roomName, identity, canPublish);
    } catch (e) {
      emit(state.copyWith(
        status: MeetingStatus.error,
        errorMessage: canPublish ? '授予权限失败：$e' : '收回权限失败：$e',
      ));
    }
  }

  /// 主持人同意某成员的举手发言申请：授予发布权限并放下其手。
  Future<void> approveHand(String identity) async {
    if (!state.isHost || identity.isEmpty) return;
    await setPublishPermission(identity, true);
    await lowerHandFor(identity);
  }

  /// 发送会议内聊天消息（DataChannel，仅本次会议有效）。
  Future<void> sendChatMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final lp = _room?.localParticipant;
    final name = (lp?.name.isNotEmpty == true) ? lp!.name : '我';
    final avatar = _avatarOf(lp);
    emit(state.copyWith(
      messages: [
        ...state.messages,
        MeetingChatMessage(
          senderIdentity: localIdentity ?? '',
          senderName: name,
          senderAvatar: avatar,
          text: trimmed,
          sentAt: DateTime.now(),
          isLocal: true,
        ),
      ],
      revision: state.revision + 1,
    ));
    await _publishData(
        {'type': 'chat', 'name': name, 'avatar': avatar, 'text': trimmed});
  }

  /// 修改会议主题（仅主持人）。
  ///
  /// 乐观更新本地状态，向其他成员实时广播，随后同步到服务端；
  /// 同步失败不回滚、不影响会议状态，仅抛出异常供 UI 提示。
  Future<void> renameTitle(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == state.title) return;
    emit(state.copyWith(title: trimmed, revision: state.revision + 1));
    await _publishData({'type': 'topic', 'title': trimmed});
    final roomName = state.roomName;
    if (roomName == null) return;
    await _meetingApi.updateMeetingTitle(roomName, trimmed);
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
    // 一次性同时申请麦克风、摄像头和通知权限（Android 13+ 前台服务通知需要）
    final permissions = [Permission.microphone, Permission.camera];
    if (lkPlatformIs(PlatformType.android)) {
      permissions.add(Permission.notification);
    }
    final statuses = await permissions.request();
    final mic = statuses[Permission.microphone] ?? PermissionStatus.denied;
    final cam = statuses[Permission.camera] ?? PermissionStatus.denied;
    // 麦克风是入会底线；摄像头拿不到（如模拟器无摄像头、用户拒绝）就以关摄像头方式入会
    if (cam != PermissionStatus.granted) {
      emit(state.copyWith(cameraEnabled: false));
    }
    return mic.isGranted;
  }

  @override
  Future<void> close() async {
    await _listener?.dispose();
    await _room?.dispose();
    return super.close();
  }
}
