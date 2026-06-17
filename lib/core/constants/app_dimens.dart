import 'package:flutter/material.dart';

/// 统一的间距、圆角、尺寸 Token
///
/// 用 [AppDimens] 替代所有手写的 `SizedBox` 与 `EdgeInsets`，保证整 App 的
/// 节奏一致。命名尽量语义化：s 表示 spacing，r 表示 radius。
class AppDimens {
  AppDimens._();

  // ===== 间距 =====
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s36 = 36;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  // ===== 圆角 =====
  static const double r4 = 4;
  static const double r6 = 6;
  static const double r8 = 8;
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r16 = 16;
  static const double r18 = 18;
  static const double r20 = 20;
  static const double r22 = 22;
  static const double r24 = 24;
  static const double r28 = 28;
  static const double r40 = 40;

  // ===== 常用组件尺寸 =====
  static const double avatarSmall = 36;
  static const double avatarMedium = 44;
  static const double avatarLarge = 56;

  static const double iconSmall = 16;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const double iconXLarge = 28;

  static const double buttonHeight = 48;
  static const double fabSize = 48;

  // ===== 常用 EdgeInsets 快捷 =====
  static const EdgeInsets pagePadding = EdgeInsets.all(s16);
  static const EdgeInsets cardPadding = EdgeInsets.all(s16);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: s16,
    vertical: s12,
  );
  static const EdgeInsets sectionPadding = EdgeInsets.fromLTRB(
    s16,
    s24,
    s16,
    s8,
  );
  static const EdgeInsets inputContentPadding = EdgeInsets.symmetric(
    horizontal: s16,
    vertical: s14,
  );

  // ===== 常用 BorderRadius =====
  static const BorderRadius radius8 = BorderRadius.all(Radius.circular(r8));
  static const BorderRadius radius12 = BorderRadius.all(Radius.circular(r12));
  static const BorderRadius radius16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius radius20 = BorderRadius.all(Radius.circular(r20));
  static const BorderRadius radius24 = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius topRadius24 = BorderRadius.vertical(
    top: Radius.circular(r24),
  );
  static const BorderRadius bottomRadius24 = BorderRadius.vertical(
    bottom: Radius.circular(r24),
  );

  /// 消息气泡专用：用户消息左圆右尖，AI 消息右圆左尖
  static BorderRadius messageBubble({required bool isUser}) {
    return BorderRadius.only(
      topLeft: const Radius.circular(r18),
      topRight: const Radius.circular(r18),
      bottomLeft: Radius.circular(isUser ? r18 : r4),
      bottomRight: Radius.circular(isUser ? r4 : r18),
    );
  }
}
