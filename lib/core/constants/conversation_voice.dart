import 'package:flutter/material.dart';

/// 语音通话对话声音
enum ConversationVoice {
  /// 男声 - Cedar
  cedar,

  /// 男声 - Marin
  marin,

  /// 女声 - Coral
  coral,

  /// 女声 - Nova
  nova,

  /// 故事模式 - Ballad
  ballad,

  /// 知识模式 - Sage
  sage,
}

extension ConversationVoiceX on ConversationVoice {
  /// 显示名称
  String get displayName {
    switch (this) {
      case ConversationVoice.cedar:
        return 'Cedar';
      case ConversationVoice.marin:
        return 'Marin';
      case ConversationVoice.coral:
        return 'Coral';
      case ConversationVoice.nova:
        return 'Nova';
      case ConversationVoice.ballad:
        return 'Ballad';
      case ConversationVoice.sage:
        return 'Sage';
    }
  }

  /// 分类标签
  String get category {
    switch (this) {
      case ConversationVoice.cedar:
      case ConversationVoice.marin:
        return '男声';
      case ConversationVoice.coral:
      case ConversationVoice.nova:
        return '女声';
      case ConversationVoice.ballad:
        return '故事模式';
      case ConversationVoice.sage:
        return '知识模式';
    }
  }

  /// 分类图标
  IconData get categoryIcon {
    switch (category) {
      case '男声':
        return Icons.male;
      case '女声':
        return Icons.female;
      case '故事模式':
        return Icons.menu_book;
      case '知识模式':
      default:
        return Icons.psychology;
    }
  }

  /// 发送给后端/OpenAI 的 voice 字段值
  String get serverValue => name;

  static ConversationVoice fromString(String? value) {
    switch (value) {
      case 'cedar':
        return ConversationVoice.cedar;
      case 'marin':
        return ConversationVoice.marin;
      case 'coral':
        return ConversationVoice.coral;
      case 'nova':
        return ConversationVoice.nova;
      case 'ballad':
        return ConversationVoice.ballad;
      case 'sage':
        return ConversationVoice.sage;
      default:
        return ConversationVoice.coral;
    }
  }
}
