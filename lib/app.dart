import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/theme/app_theme.dart';
import 'src/core/widgets/connectivity_banner.dart';
import 'src/features/settings/providers.dart';
import 'src/routing/app_router.dart';

class GeekyApp extends ConsumerWidget {
  const GeekyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final router = ref.watch(appRouterProvider);

    final scaleFactor = switch (fontSize) {
      FontSizeOption.small => 0.9,
      FontSizeOption.medium => 1.0,
      FontSizeOption.large => 1.15,
    };

    return MaterialApp.router(
      title: 'Geeky',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final scaled = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scaleFactor)),
          child: child ?? const SizedBox.shrink(),
        );
        return ConnectivityBanner(child: scaled);
      },
    );
  }
}
