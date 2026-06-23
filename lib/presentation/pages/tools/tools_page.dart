import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bdx/bdx.dart';
import '../../widgets/tech_background.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final tools = [
      _ToolItem(
        icon: Icons.translate,
        title: 'AI 翻译',
        subtitle: '精准翻译多语言内容',
        color: const Color(0xFF4FACFE),
        scene: 'translator',
      ),
      _ToolItem(
        icon: Icons.code,
        title: '代码解释',
        subtitle: '解释、Debug、优化代码',
        color: AppColors.success,
        scene: 'code_explain',
      ),
      _ToolItem(
        icon: Icons.calendar_today,
        title: '周报生成',
        subtitle: '输入要点生成周报',
        color: const Color(0xFFFFA726),
        scene: 'weekly_report',
      ),
      _ToolItem(
        icon: Icons.edit_note,
        title: '文案改写',
        subtitle: '润色改写各种文案',
        color: AppColors.primaryLight,
        scene: 'rewrite',
      ),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: TechBackground(
        child: Column(
          children: [
            AppHeader(
              title: '实用工具',
              leading: BdxIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                backgroundColor: Colors.transparent,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.s16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppDimens.s12,
                    mainAxisSpacing: AppDimens.s12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: tools.length,
                  itemBuilder: (context, index) => _buildToolCard(context, tools[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, _ToolItem tool) {
    final colors = AppColors.of(context);

    return PressScale(
      onTap: () => context.push('/chat/detail?scene=${tool.scene}'),
      child: GlassCard(
        borderRadius: AppDimens.r18,
        padding: const EdgeInsets.all(AppDimens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tool.color.withValues(alpha: 0.9),
                    tool.color.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppDimens.r14),
              ),
              child: Icon(tool.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: AppDimens.s14),
            Text(
              tool.title,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.s4),
            Text(
              tool.subtitle,
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String scene;

  const _ToolItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.scene,
  });
}
