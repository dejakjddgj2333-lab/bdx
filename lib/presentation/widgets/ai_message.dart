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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: MarkdownBody(
              data: text.isEmpty ? ' ' : text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
                code: const TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.transparent,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFF1A1D2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                codeblockPadding: const EdgeInsets.all(12),
                blockquote: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
                blockquoteDecoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                ),
                blockquotePadding: const EdgeInsets.only(left: 12),
                a: const TextStyle(color: AppColors.primaryLight),
                listBullet: const TextStyle(color: Colors.white),
                h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
                h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ),
          if (model != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 6),
              child: Text(
                model!,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
