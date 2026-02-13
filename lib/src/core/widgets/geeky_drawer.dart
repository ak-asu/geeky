import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class DrawerSection {
  const DrawerSection({required this.label, required this.items});

  final String label;
  final List<DrawerItem> items;
}

class DrawerItem {
  const DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isPremium = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isPremium;
}

class GeekyDrawer extends StatelessWidget {
  const GeekyDrawer({
    super.key,
    required this.sections,
    this.header,
    this.footer,
  });

  final List<DrawerSection> sections;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[
              Padding(padding: AppSpacing.paddingAll16, child: header!),
              const Divider(height: 1),
            ],
            Expanded(
              child: ListView(
                padding: AppSpacing.paddingV8,
                children: [
                  for (final section in sections) ...[
                    _SectionHeader(label: section.label),
                    for (final item in section.items) _DrawerTile(item: item),
                    AppSpacing.gapV8,
                  ],
                ],
              ),
            ),
            if (footer != null) ...[
              const Divider(height: 1),
              Padding(padding: AppSpacing.paddingAll16, child: footer!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s4,
      ),
      child: Text(
        label.toUpperCase(),
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.item});

  final DrawerItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        item.icon,
        size: 22,
        color: context.colorScheme.onSurfaceVariant,
      ),
      title: Text(item.label, style: context.textTheme.bodyMedium),
      trailing: item.isPremium
          ? const Icon(Icons.lock_rounded, size: 16, color: AppColors.primary)
          : item.trailing,
      dense: true,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      onTap: () {
        Navigator.of(context).pop();
        item.onTap();
      },
    );
  }
}
