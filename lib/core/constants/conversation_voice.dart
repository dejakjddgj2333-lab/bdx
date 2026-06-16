import 'package:flutter/material.dart';

/// 语音通话对话声音
enum ConversationVoice {
  /// 温暖客服女声 - Tina
  tina,

  /// 台湾腔女声 - Cindy
  cindy,

  /// 温柔治愈女声 - Liora Mira
  lioraMira,

  /// 活泼开朗女声 - Sunnybobi
  sunnybobi,

  /// 清晰稳重男声 - Raymond
  raymond,
}

extension ConversationVoiceX on ConversationVoice {
  /// 中文显示名称
  String get displayName {
    switch (this) {
      case ConversationVoice.tina:
        return '温暖客服女声';
      case ConversationVoice.cindy:
        return '台湾腔女声';
      case ConversationVoice.lioraMira:
        return '温柔治愈女声';
      case ConversationVoice.sunnybobi:
        return '活泼开朗女声';
      case ConversationVoice.raymond:
        return '清晰稳重男声';
    }
  }

  /// 音色特点
  String get description {
    switch (this) {
      case ConversationVoice.tina:
        return '温暖自然，亲和力强，类似客服/助手风格';
      case ConversationVoice.cindy:
        return '台湾女生声线，带轻微台湾腔';
      case ConversationVoice.lioraMira:
        return '温柔治愈型女声';
      case ConversationVoice.sunnybobi:
        return '活泼开朗，邻家女孩风格';
      case ConversationVoice.raymond:
        return '清晰稳重男声';
    }
  }

  /// 适合场景
  String get scenario {
    switch (this) {
      case ConversationVoice.tina:
        return '通用对话、AI助手';
      case ConversationVoice.cindy:
        return '中文聊天、陪伴类产品';
      case ConversationVoice.lioraMira:
        return '情感陪伴、有声阅读';
      case ConversationVoice.sunnybobi:
        return '社交机器人、娱乐互动';
      case ConversationVoice.raymond:
        return '客服、播报、助手类应用';
    }
  }

  /// 分类：男声/女声
  String get category {
    switch (this) {
      case ConversationVoice.raymond:
        return '男声';
      case ConversationVoice.tina:
      case ConversationVoice.cindy:
      case ConversationVoice.lioraMira:
      case ConversationVoice.sunnybobi:
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

  /// 发送给后端的 voice 字段值（必须与后端参数完全一致）
  String get serverValue {
    switch (this) {
      case ConversationVoice.tina:
        return 'Tina';
      case ConversationVoice.cindy:
        return 'Cindy';
      case ConversationVoice.lioraMira:
        return 'Liora Mira';
      case ConversationVoice.sunnybobi:
        return 'Sunnybobi';
      case ConversationVoice.raymond:
        return 'Raymond';
    }
  }

  static ConversationVoice fromString(String? value) {
    switch (value) {
      case 'tina':
      case 'Tina':
        return ConversationVoice.tina;
      case 'cindy':
      case 'Cindy':
        return ConversationVoice.cindy;
      case 'lioraMira':
      case 'Liora Mira':
        return ConversationVoice.lioraMira;
      case 'sunnybobi':
      case 'Sunnybobi':
        return ConversationVoice.sunnybobi;
      case 'raymond':
      case 'Raymond':
        return ConversationVoice.raymond;
      default:
        return ConversationVoice.tina;
    }
  }
}
