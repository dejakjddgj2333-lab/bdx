/// 语音通话厂商配置（由后端 /voice-call/provider 返回）
class VoiceProviderConfig {
  final String provider;
  final String name;
  final String? realtimeModel;
  final List<String> voices;
  final Map<String, String> voiceLabels;
  final String defaultVoice;

  const VoiceProviderConfig({
    required this.provider,
    required this.name,
    this.realtimeModel,
    required this.voices,
    required this.voiceLabels,
    required this.defaultVoice,
  });

  factory VoiceProviderConfig.fromJson(Map<String, dynamic> json) {
    final voicesJson = json['voices'];
    final voices = voicesJson is List
        ? voicesJson.whereType<String>().toList()
        : <String>[];

    final labelsJson = json['voice_labels'];
    final labels = labelsJson is Map
        ? labelsJson.map((key, value) => MapEntry(key.toString(), value.toString()))
        : <String, String>{};

    return VoiceProviderConfig(
      provider: json['provider']?.toString() ?? 'qwen',
      name: json['name']?.toString() ?? '阿里百炼实时多模态',
      realtimeModel: json['realtime_model']?.toString(),
      voices: voices.isEmpty ? const ['zhiyan'] : voices,
      voiceLabels: labels,
      defaultVoice: json['default_voice']?.toString() ?? voices.firstOrNull ?? 'zhiyan',
    );
  }

  String labelFor(String voice) => voiceLabels[voice] ?? voice;

  VoiceProviderConfig copyWith({
    String? provider,
    String? name,
    String? realtimeModel,
    List<String>? voices,
    Map<String, String>? voiceLabels,
    String? defaultVoice,
  }) {
    return VoiceProviderConfig(
      provider: provider ?? this.provider,
      name: name ?? this.name,
      realtimeModel: realtimeModel ?? this.realtimeModel,
      voices: voices ?? this.voices,
      voiceLabels: voiceLabels ?? this.voiceLabels,
      defaultVoice: defaultVoice ?? this.defaultVoice,
    );
  }
}
