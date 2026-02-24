import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers.dart';
import '../../../subscription/providers.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
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

          // --- Privacy ---
          const _SectionHeader(label: 'Privacy'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Export My Data',
            trailing: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
            onTap: _exporting ? null : _handleExportData,
          ),

          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: Icon(
              Icons.open_in_new_rounded,
              size: 20,
              color: context.colorScheme.onSurfaceVariant,
            ),
            onTap: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl)),
          ),

          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account',
            titleColor: AppColors.error,
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            onTap: _showDeleteAccountDialog,
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
            onTap: _showClearCacheDialog,
          ),

          _SettingsTile(
            icon: Icons.restart_alt_rounded,
            title: 'Reset All Data',
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            onTap: _showResetDialog,
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

  Future<void> _handleExportData() async {
    setState(() => _exporting = true);
    try {
      await ref.read(settingsRepositoryProvider).exportData();
      if (mounted) {
        context.showSnackBar('Your data export is ready.');
      }
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Export failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete your account and all associated data. This cannot be undone.',
                ),
                AppSpacing.gapV16,
                const Text(
                  'Type DELETE to confirm:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                AppSpacing.gapV8,
                TextField(
                  controller: confirmController,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'DELETE',
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: confirmController.text == 'DELETE'
                    ? () async {
                        Navigator.of(ctx).pop();
                        await _handleDeleteAccount();
                      }
                    : null,
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    try {
      await ref.read(settingsRepositoryProvider).deleteAccount();
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Failed to delete account. Please try again.');
      }
    }
  }

  void _showClearCacheDialog() {
    showDialog<void>(
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

  void _showResetDialog() {
    showDialog<void>(
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
              if (mounted) {
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
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: context.colorScheme.onSurfaceVariant),
          AppSpacing.gapH12,
          Expanded(
            child: Text(
              title,
              style: context.textTheme.bodyMedium?.copyWith(color: titleColor),
            ),
          ),
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
