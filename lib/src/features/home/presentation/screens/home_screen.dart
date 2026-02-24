import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/share_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_drawer.dart';
import '../../../../core/widgets/geeky_scaffold.dart';
import '../../../../core/widgets/paywall_sheet.dart';
import '../../../../routing/route_names.dart';
import '../../../subscription/providers.dart';
import '../widgets/adaptive_feed.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    // Deliver any share intent that arrived before the user was on this screen
    // (e.g. cold-start share while unauthenticated — stored in pendingShareProvider
    // by app.dart, then picked up here after login redirects to home).
    ref.listen(pendingShareProvider, (_, next) {
      if (next == null) return;
      ref.read(pendingShareProvider.notifier).clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (next.text != null) {
          context.pushNamed(RouteNames.createNote, extra: next);
        } else if (next.filePath != null) {
          context.pushNamed(RouteNames.uploadMedia, extra: next);
        }
      });
    });

    return GeekyScaffold(
      drawer: _buildDrawer(context, ref, isPremium),
      actions: [
        // Search
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
          onPressed: () => context.pushNamed(RouteNames.search),
        ),
        // Notifications
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: () => context.pushNamed(RouteNames.notifications),
        ),
      ],
      body: const AdaptiveFeed(),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, bool isPremium) {
    return GeekyDrawer(
      header: Row(
        children: [
          Semantics(
            label: 'User profile picture',
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: const Icon(Icons.person_rounded, color: AppColors.primary),
            ),
          ),
          AppSpacing.gapH12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Geeky',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  isPremium ? 'Premium' : 'Free',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: isPremium
                        ? AppColors.primary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      sections: [
        DrawerSection(
          label: 'Learn',
          items: [
            DrawerItem(
              icon: Icons.view_module_rounded,
              label: 'Modules',
              onTap: () => context.pushNamed(RouteNames.modulesList),
            ),
            DrawerItem(
              icon: Icons.hub_rounded,
              label: 'Knowledge Graph',
              isPremium: !isPremium,
              onTap: () => isPremium
                  ? context.pushNamed(RouteNames.knowledgeGraph)
                  : PaywallSheet.show(context, featureName: 'Knowledge Graph'),
            ),
            DrawerItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Ask Geeky',
              isPremium: !isPremium,
              onTap: () => isPremium
                  ? context.pushNamed(RouteNames.ragQuery)
                  : PaywallSheet.show(context, featureName: 'Ask Geeky'),
            ),
            DrawerItem(
              icon: Icons.quiz_rounded,
              label: 'Quiz & Review',
              isPremium: !isPremium,
              onTap: () => isPremium
                  ? context.pushNamed(RouteNames.quiz)
                  : PaywallSheet.show(context, featureName: 'Quiz & Review'),
            ),
          ],
        ),
        DrawerSection(
          label: 'Manage',
          items: [
            DrawerItem(
              icon: Icons.note_rounded,
              label: 'Notes',
              onTap: () => context.pushNamed(RouteNames.notesList),
            ),
            DrawerItem(
              icon: Icons.source_rounded,
              label: 'Sources',
              onTap: () => context.pushNamed(RouteNames.sourcesList),
            ),
            DrawerItem(
              icon: Icons.bookmark_rounded,
              label: 'Bookmarks',
              onTap: () => context.pushNamed(RouteNames.bookmarks),
            ),
          ],
        ),
        DrawerSection(
          label: 'You',
          items: [
            DrawerItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              onTap: () => context.pushNamed(RouteNames.profile),
            ),
            DrawerItem(
              icon: Icons.analytics_rounded,
              label: 'Analytics',
              isPremium: !isPremium,
              onTap: () => isPremium
                  ? context.pushNamed(RouteNames.analytics)
                  : PaywallSheet.show(context, featureName: 'Analytics'),
            ),
            DrawerItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () => context.pushNamed(RouteNames.settings),
            ),
          ],
        ),
      ],
      footer: ListTile(
        leading: const Icon(Icons.store_rounded, size: 22),
        title: Text('Module Store', style: context.textTheme.bodyMedium),
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
        onTap: () {
          Navigator.of(context).pop();
          context.pushNamed(RouteNames.store);
        },
      ),
    );
  }
}
