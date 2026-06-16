import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBorder;

  const AppHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final colors = AppColors.of(context);

    return Container(
      padding: EdgeInsets.only(top: statusBarHeight + 8, left: 8, right: 8, bottom: 10),
      decoration: BoxDecoration(
        color: colors.bg.withOpacity(0.92),
        border: showBorder
            ? Border(bottom: BorderSide(color: colors.border.withOpacity(0.5)))
            : null,
      ),
      child: Row(
        children: [
          if (leading != null)
            leading!
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actions != null)
            Row(mainAxisSize: MainAxisSize.min, children: actions!)
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
