import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_handler/share_handler.dart';

import 'src/core/providers/share_provider.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/widgets/connectivity_banner.dart';
import 'src/features/auth/providers.dart';
import 'src/features/offline/providers.dart';
import 'src/features/settings/providers.dart';
import 'src/routing/app_router.dart';
import 'src/routing/route_names.dart';

class GeekyApp extends ConsumerStatefulWidget {
  const GeekyApp({super.key});

  @override
  ConsumerState<GeekyApp> createState() => _GeekyAppState();
}

class _GeekyAppState extends ConsumerState<GeekyApp> {
  StreamSubscription<SharedMedia>? _shareSub;

  @override
  void initState() {
    super.initState();
    _initShareHandler();
  }

  Future<void> _initShareHandler() async {
    final handler = ShareHandlerPlatform.instance;

    // Handle share that launched the app from a closed state
    final initial = await handler.getInitialSharedMedia();
    if (initial != null && mounted) {
      _processShare(initial);
    }

    // Handle shares while the app is already running
    _shareSub = handler.sharedMediaStream.listen((media) {
      if (mounted) _processShare(media);
    });
  }

  void _processShare(SharedMedia media) {
    ShareContent? content;

    if (media.content != null && media.content!.trim().isNotEmpty) {
      content = ShareContent(text: media.content!.trim());
    } else if (media.attachments?.isNotEmpty == true) {
      final att = media.attachments!.first;
      if (att != null) {
        content = ShareContent(
          filePath: att.path,
          mimeType: att.type.toString(),
        );
      }
    }

    if (content == null) return;

    final isLoggedIn = ref.read(isLoggedInProvider);
    if (isLoggedIn) {
      // App is active and user is authenticated — navigate immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigateToShare(content!);
      });
    } else {
      // Not logged in — store for HomeScreen to handle after login
      ref.read(pendingShareProvider.notifier).set(content);
    }
  }

  void _navigateToShare(ShareContent content) {
    final router = ref.read(appRouterProvider);
    if (content.text != null) {
      router.pushNamed(RouteNames.createNote, extra: content);
    } else if (content.filePath != null) {
      router.pushNamed(RouteNames.uploadMedia, extra: content);
    }
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Activate auto-sync when connectivity is restored
    ref.watch(syncOnReconnectProvider);

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
