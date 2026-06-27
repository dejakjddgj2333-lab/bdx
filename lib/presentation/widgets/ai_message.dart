import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/bdx_animations.dart';
import 'bdx/bdx.dart';

class AiMessage extends StatelessWidget {
  final dynamic content;
  final String? model;

  /// 提取代码块的正则。提为 static final 避免每次 build 重新编译。
  static final RegExp _codeBlockPattern = RegExp(r'```([^\n]*)\n([\s\S]*?)```');

  const AiMessage({super.key, this.content, this.model});

  @override
  Widget build(BuildContext context) {
    final text = content?.toString() ?? '';
    final colors = AppColors.of(context);

    return BdxAnimations.messageEnter(
      Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.s8,
          horizontal: AppDimens.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              useBlur: true,
              borderRadius: AppDimens.r18,
              customBorderRadius: AppDimens.messageBubble(isUser: false),
              borderColor: colors.borderSubtle,
              padding: const EdgeInsets.all(AppDimens.s14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildContent(text, context),
              ),
            ),
            if (model != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppDimens.s6,
                  left: AppDimens.s6,
                ),
                child: Text(
                  model!,
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: AppDimens.s12,
                  ),
                ),
              ),
          ],
        ),
      ),
      isUser: false,
    );
  }

  List<Widget> _buildContent(String text, BuildContext context) {
    if (text.isEmpty) {
      return [
        MarkdownBody(
          data: ' ',
          styleSheet: _buildMarkdownStyle(context),
        ),
      ];
    }

    final widgets = <Widget>[];
    final pattern = _codeBlockPattern;
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        widgets.add(
          MarkdownBody(
            data: text.substring(lastEnd, match.start),
            styleSheet: _buildMarkdownStyle(context),
          ),
        );
      }

      final language = match.group(1)?.trim();
      final code = match.group(2) ?? '';
      widgets.add(
        BdxCodeBlock(
          code: code,
          language: language?.isEmpty == true ? null : language,
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      widgets.add(
        MarkdownBody(
          data: text.substring(lastEnd),
          styleSheet: _buildMarkdownStyle(context),
        ),
      );
    }

    return widgets;
  }

  MarkdownStyleSheet _buildMarkdownStyle(BuildContext context) {
    final colors = AppColors.of(context);

    return MarkdownStyleSheet(
      p: TextStyle(color: colors.text, fontSize: 15, height: 1.6),
      code: TextStyle(
        color: colors.text,
        backgroundColor: Colors.transparent,
        fontSize: 13,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppDimens.r12),
        border: Border.all(color: colors.borderSubtle),
      ),
      codeblockPadding: const EdgeInsets.all(AppDimens.s12),
      blockquote: TextStyle(
        color: colors.textSecondary,
        fontSize: 15,
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.border, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: AppDimens.s12),
      a: const TextStyle(color: AppColors.primaryLight),
      listBullet: TextStyle(color: colors.text),
      h1: TextStyle(
        color: colors.text,
        fontWeight: FontWeight.bold,
        fontSize: 22,
      ),
      h2: TextStyle(
        color: colors.text,
        fontWeight: FontWeight.bold,
        fontSize: 19,
      ),
      h3: TextStyle(
        color: colors.text,
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
    );
  }
}
