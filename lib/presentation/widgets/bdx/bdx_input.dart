import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import 'glass_card.dart';

class BdxInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final Widget? prefix;
  final Widget? suffix;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final TapRegionCallback? onTapOutside;

  const BdxInput({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.prefix,
    this.suffix,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.contentPadding,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GlassCard(
      useBlur: true,
      borderRadius: AppDimens.r16,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          if (prefix != null) ...[
            const SizedBox(width: AppDimens.s12),
            prefix!,
            const SizedBox(width: AppDimens.s8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
              onTapOutside: onTapOutside ?? (_) => FocusManager.instance.primaryFocus?.unfocus(),
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              minLines: minLines,
              obscureText: obscureText,
              autofocus: autofocus,
              enabled: enabled,
              style: TextStyle(color: colors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: colors.textTertiary),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: contentPadding ??
                    const EdgeInsets.symmetric(
                      horizontal: AppDimens.s16,
                      vertical: AppDimens.s14,
                    ),
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: AppDimens.s8),
            suffix!,
            const SizedBox(width: AppDimens.s12),
          ],
        ],
      ),
    );
  }
}
