import 'package:flutter/material.dart';

/// 语音通话音色（阶段二：火山方舟 Plan TTS doubao-seed-tts-2.0）
///
/// serverValue 为方舟 speaker ID（对应后台 tts_voices 表暴露的音色）。
/// 完整音色库由后台管理，App 此处保留常用枚举；若后端默认音色不在枚举内，
/// 仍可通过 selectedVoice 直接传 speaker ID。
enum ConversationVoice {
  /// 治愈女声 - Vivi 2.0
  vivi,

  /// 活泼妹妹 - 小何 2.0
  xiaohe,

  /// 温暖少年 - 温暖阿虎 2.0
  alvin,

  /// 解说男声 - 解说明小明 2.0
  xiaoming,

  /// 温柔妈妈 2.0
  mama,
}

extension ConversationVoiceX on ConversationVoice {
  /// 中文显示名称
  String get displayName {
    switch (this) {
      case ConversationVoice.vivi:
        return 'Vivi 2.0';
      case ConversationVoice.xiaohe:
        return '小何 2.0';
      case ConversationVoice.alvin:
        return '温暖阿虎 2.0';
      case ConversationVoice.xiaoming:
        return '解说小明 2.0';
      case ConversationVoice.mama:
        return '温柔妈妈 2.0';
    }
  }

  /// 音色特点
  String get description {
    switch (this) {
      case ConversationVoice.vivi:
        return '语调平稳、咬字柔和、自带治愈安抚力';
      case ConversationVoice.xiaohe:
        return '声线甜美有活力，活泼开朗';
      case ConversationVoice.alvin:
        return '声线阳光温暖、语气亲切的少年音';
      case ConversationVoice.xiaoming:
        return '语速明快、中气十足的解说男声';
      case ConversationVoice.mama:
        return '语调舒缓、咬字温润的治愈女声';
    }
  }

  /// 适合场景
  String get scenario {
    switch (this) {
      case ConversationVoice.vivi:
        return '通用对话、AI 助手';
      case ConversationVoice.xiaohe:
        return '社交陪伴、娱乐互动';
      case ConversationVoice.alvin:
        return '日常聊天、助手类';
      case ConversationVoice.xiaoming:
        return '播报、解说类';
      case ConversationVoice.mama:
        return '情感陪伴、有声阅读';
    }
  }

  /// 分类：男声/女声
  String get category {
    switch (this) {
      case ConversationVoice.alvin:
      case ConversationVoice.xiaoming:
        return '男声';
      case ConversationVoice.vivi:
      case ConversationVoice.xiaohe:
      case ConversationVoice.mama:
        return '女声';
    }
  }

  /// 分类图标
  IconData get categoryIcon {
    switch (category) {
      case '男声':
        return Icons.male;
      case '女声':
      default:
        return Icons.female;
    }
  }

  /// 发送给后端的 voice 字段值（方舟 speaker ID，必须与 tts_voices.speaker 一致）
  String get serverValue {
    switch (this) {
      case ConversationVoice.vivi:
        return 'zh_female_vv_uranus_bigtts';
      case ConversationVoice.xiaohe:
        return 'zh_female_xiaohe_uranus_bigtts';
      case ConversationVoice.alvin:
        return 'zh_male_wennuanahu_uranus_bigtts';
      case ConversationVoice.xiaoming:
        return 'zh_male_jieshuoxiaoming_uranus_bigtts';
      case ConversationVoice.mama:
        return 'zh_female_wenroumama_uranus_bigtts';
    }
  }

  static ConversationVoice fromString(String? value) {
    if (value == null) return ConversationVoice.vivi;
    // 先匹配 speaker ID（方舟）
    for (final v in ConversationVoice.values) {
      if (v.serverValue == value) return v;
    }
    // 兼容枚举名
    switch (value) {
      case 'vivi':
        return ConversationVoice.vivi;
      case 'xiaohe':
        return ConversationVoice.xiaohe;
      case 'alvin':
        return ConversationVoice.alvin;
      case 'xiaoming':
        return ConversationVoice.xiaoming;
      case 'mama':
        return ConversationVoice.mama;
      default:
        return ConversationVoice.vivi;
    }
  }
}
