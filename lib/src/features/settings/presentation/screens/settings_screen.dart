import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // --- Appearance ---
          const _SectionHeader(label: 'Appearance'),
          AppSpacing.gapV8,

          // Theme mode
          _SettingsTile(
            icon: Icons.palette_rounded,
            title: 'Theme',
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.contrast_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selected) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selected.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          // Font size
          _SettingsTile(
            icon: Icons.text_fields_rounded,
            title: 'Font Size',
            trailing: SegmentedButton<FontSizeOption>(
              segments: const [
                ButtonSegment(value: FontSizeOption.small, label: Text('S')),
                ButtonSegment(value: FontSizeOption.medium, label: Text('M')),
                ButtonSegment(value: FontSizeOption.large, label: Text('L')),
              ],
              selected: {fontSize},
              onSelectionChanged: (selected) {
                ref.read(fontSizeProvider.notifier).setFontSize(selected.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          AppSpacing.gapV24,

          // --- About ---
          const _SectionHeader(label: 'About'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Version',
            trailing: Text(
              '1.0.0-dev',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: context.textTheme.labelSmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.colorScheme.onSurfaceVariant),
          AppSpacing.gapH12,
          Expanded(child: Text(title, style: context.textTheme.bodyMedium)),
          trailing,
        ],
      ),
    );
  }
}
