import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../subscription/providers.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final ttsEnabled = prefs.getBool(StorageKeys.ttsEnabled) ?? false;
    final notificationsEnabled =
        prefs.getBool(StorageKeys.notificationsEnabled) ?? true;
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
            trailing: SizedBox(
              width: 160,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
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
          ),

          // Font size
          _SettingsTile(
            icon: Icons.text_fields_rounded,
            title: 'Font Size',
            trailing: SizedBox(
              width: 160,
              child: SegmentedButton<FontSizeOption>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: FontSizeOption.small, label: Text('S')),
                  ButtonSegment(value: FontSizeOption.medium, label: Text('M')),
                  ButtonSegment(value: FontSizeOption.large, label: Text('L')),
                ],
                selected: {fontSize},
                onSelectionChanged: (selected) {
                  ref
                      .read(fontSizeProvider.notifier)
                      .setFontSize(selected.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),

          AppSpacing.gapV24,

          // --- Features ---
          const _SectionHeader(label: 'Features'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.record_voice_over_rounded,
            title: 'Text-to-Speech',
            trailing: Switch.adaptive(
              value: ttsEnabled,
              activeTrackColor: AppColors.primary,
              onChanged: isPremium
                  ? (value) => prefs.setBool(StorageKeys.ttsEnabled, value)
                  : null,
            ),
          ),
          if (!isPremium)
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                'Premium feature',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          _SettingsTile(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            trailing: Switch.adaptive(
              value: notificationsEnabled,
              activeTrackColor: AppColors.primary,
              onChanged: (value) =>
                  prefs.setBool(StorageKeys.notificationsEnabled, value),
            ),
          ),

          AppSpacing.gapV24,

          // --- Account ---
          const _SectionHeader(label: 'Account'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.workspace_premium_rounded,
            title: 'Subscription',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPremium ? 'Premium' : 'Free',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: isPremium
                        ? AppColors.primary
                        : context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                AppSpacing.gapH4,
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: () => context.pushNamed(RouteNames.subscription),
          ),

          AppSpacing.gapV24,

          // --- Data Management ---
          const _SectionHeader(label: 'Data Management'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: 'Clear Cache',
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colorScheme.onSurfaceVariant,
            ),
            onTap: () => _showClearCacheDialog(context, ref),
          ),

          _SettingsTile(
            icon: Icons.restart_alt_rounded,
            title: 'Reset All Data',
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            onTap: () => _showResetDialog(context, ref),
          ),

          AppSpacing.gapV24,

          // --- About ---
          const _SectionHeader(label: 'About'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Version',
            trailing: Text(
              '${AppConstants.appVersion}-dev',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove cached content. Your notes and bookmarks will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.showSnackBar('Cache cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will delete all local data including notes, bookmarks, and settings. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final prefs = ref.read(sharedPreferencesProvider);
              await prefs.clear();
              if (context.mounted) {
                context.showSnackBar('All data reset. Restart the app.');
              }
            },
            child: const Text('Reset'),
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
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

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: content,
      );
    }

    return content;
  }
}
