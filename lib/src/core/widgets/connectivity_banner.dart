import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/context_extensions.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_spacing.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isOffline ? null : 0,
          child: isOffline
              ? MaterialBanner(
                  padding: AppSpacing.paddingV8H16,
                  content: Text(
                    'You are offline. Some features may be limited.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onErrorContainer,
                    ),
                  ),
                  leading: Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: context.colorScheme.onErrorContainer,
                  ),
                  backgroundColor: context.colorScheme.errorContainer,
                  actions: const [SizedBox.shrink()],
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}
