import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers.dart';
import '../../../location/providers.dart';
import '../../../subscription/providers.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;
  bool _detectingLocation = false;
  bool _clearingOfflineData = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final ttsEnabled = prefs.getBool(StorageKeys.ttsEnabled) ?? false;
    final notificationsEnabled =
        prefs.getBool(StorageKeys.notificationsEnabled) ?? true;
    final locationEnabled = ref.watch(locationEnabledProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final locationPref = ref.watch(locationPreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // ── Appearance ────────────────────────────────────────────────
          const _SectionHeader(label: 'Appearance'),
          AppSpacing.gapV8,

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

          // ── Features ──────────────────────────────────────────────────
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

          _SettingsTile(
            icon: Icons.location_on_rounded,
            title: 'Location Personalization',
            trailing: Switch.adaptive(
              value: locationEnabled,
              activeTrackColor: AppColors.primary,
              onChanged: (value) async {
                await ref.read(locationEnabledProvider.notifier).set(value);
                if (value) {
                  // Trigger immediate resolution when the user enables it.
                  ref
                      .read(locationContextProvider.notifier)
                      .refresh()
                      .ignore();
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              'Surfaces content relevant to your region',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          AppSpacing.gapV24,

          // --- Location ---
          const _SectionHeader(label: 'Location'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.location_on_rounded,
            title: 'Prioritize local content',
            trailing: Switch.adaptive(
              value: locationPref.enabled,
              activeTrackColor: AppColors.primary,
              onChanged: (value) => ref
                  .read(locationPreferenceProvider.notifier)
                  .setEnabled(value),
            ),
          ),

          if (locationPref.enabled) ...[
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                'Content from your region gets a small ranking boost (~12%)',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AppSpacing.gapV4,
            _SettingsTile(
              icon: Icons.my_location_rounded,
              title: locationPref.homeRegion != null
                  ? locationPref.homeRegion!
                  : 'No region set',
              trailing: _detectingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Auto-detect button
                        IconButton(
                          tooltip: 'Auto-detect',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.gps_fixed_rounded,
                            size: 20,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: _detectingLocation
                              ? null
                              : _handleDetectLocation,
                        ),
                        // Manual edit button
                        IconButton(
                          tooltip: 'Set manually',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          onPressed: _showManualRegionDialog,
                        ),
                      ],
                    ),
            ),
          ],

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

          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colorScheme.onSurfaceVariant,
            ),
            onTap: _showSignOutDialog,
          ),

          AppSpacing.gapV24,

          // ── Privacy & Data ────────────────────────────────────────────
          const _SectionHeader(label: 'Privacy & Data'),
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

          AppSpacing.gapV24,

          // ── Storage ───────────────────────────────────────────────────
          const _SectionHeader(label: 'Storage'),
          AppSpacing.gapV8,

          _SettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: 'Clear Offline Data',
            trailing: _clearingOfflineData
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
            onTap: _clearingOfflineData ? null : _showClearOfflineDataDialog,
          ),

          AppSpacing.gapV24,

          // ── Danger Zone ───────────────────────────────────────────────
          const _SectionHeader(label: 'Danger Zone'),
          AppSpacing.gapV8,

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

          // ── About ─────────────────────────────────────────────────────
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

  Future<void> _handleDetectLocation() async {
    setState(() => _detectingLocation = true);
    try {
      final result = await ref
          .read(locationPreferenceProvider.notifier)
          .detectRegion();
      if (!mounted) return;
      switch (result) {
        case LocationSuccess(:final region):
          context.showSnackBar('Region set to $region');
        case LocationDenied():
          context.showSnackBar(
            'Location permission denied. Set your region manually.',
          );
        case LocationDisabled():
          context.showSnackBar(
            'Location services are disabled. Enable them in device settings.',
          );
        case LocationError(:final message):
          context.showSnackBar('Could not detect location: $message');
      }
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  void _showManualRegionDialog() {
    final controller = TextEditingController(
      text: ref.read(locationPreferenceProvider).homeRegion ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Home Region'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your city or state, e.g. "Arizona, US"'),
            AppSpacing.gapV12,
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Arizona, US',
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
          if (ref.read(locationPreferenceProvider).homeRegion != null)
            TextButton(
              onPressed: () {
                ref.read(locationPreferenceProvider.notifier).clearRegion();
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                ref.read(locationPreferenceProvider.notifier).setRegion(value);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _handleExportData() async {
    setState(() => _exporting = true);
    try {
      await ref.read(settingsRepositoryProvider).exportData();
      if (mounted) {
        context.showSnackBar(
          "Export queued. You'll receive an email with a download link.",
        );
      }
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Export failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSignOutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _showClearOfflineDataDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Offline Data'),
        content: const Text(
          'This removes locally cached notes, shorts, modules, and images '
          'from this device. Your data is safe on the server and will '
          're-sync automatically when you are online.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _handleClearOfflineData();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClearOfflineData() async {
    setState(() => _clearingOfflineData = true);
    try {
      final userId = ref.read(currentUserProvider)?.id ?? '';
      await ref.read(settingsRepositoryProvider).clearOfflineData(userId);
      if (mounted) {
        context.showSnackBar(
          'Offline data cleared. Content will re-sync when online.',
        );
      }
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Failed to clear offline data. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _clearingOfflineData = false);
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
                  'This will permanently delete your account and all associated '
                  'data. This cannot be undone.',
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
      // RouterNotifier detects the auth state change and redirects to /login.
    } catch (_) {
      if (mounted) {
        context.showSnackBar('Failed to delete account. Please try again.');
      }
    }
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

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
