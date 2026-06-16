import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/constants/app_colors.dart';

class AiMessage extends StatelessWidget {
  final dynamic content;
  final String? model;

  const AiMessage({super.key, this.content, this.model});

  @override
  Widget build(BuildContext context) {
    final text = content?.toString() ?? '';
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.glassWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: MarkdownBody(
              data: text.isEmpty ? ' ' : text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: colors.text, fontSize: 15, height: 1.6),
                code: TextStyle(
                  color: colors.text,
                  backgroundColor: Colors.transparent,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: colors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.borderSubtle),
                ),
                codeblockPadding: const EdgeInsets.all(12),
                blockquote: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(left: BorderSide(color: colors.border, width: 3)),
                ),
                blockquotePadding: const EdgeInsets.only(left: 12),
                a: const TextStyle(color: AppColors.primaryLight),
                listBullet: TextStyle(color: colors.text),
                h1: TextStyle(color: colors.text, fontWeight: FontWeight.bold, fontSize: 22),
                h2: TextStyle(color: colors.text, fontWeight: FontWeight.bold, fontSize: 19),
                h3: TextStyle(color: colors.text, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ),
          if (model != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 6),
              child: Text(
                model!,
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
