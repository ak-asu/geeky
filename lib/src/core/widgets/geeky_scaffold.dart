import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_spacing.dart';

class GeekyScaffold extends StatelessWidget {
  const GeekyScaffold({
    super.key,
    required this.body,
    this.drawer,
    this.title,
    this.actions,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  final Widget body;
  final Widget? drawer;
  final String? title;
  final List<Widget>? actions;
  final bool showAppBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      body: showAppBar
          ? NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: context.colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  leading: Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  title: title != null
                      ? Text(
                          title!,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  centerTitle: true,
                  actions: [
                    ...?actions,
                    const SizedBox(width: AppSpacing.s8),
                  ],
                ),
              ],
              body: body,
            )
          : body,
    );
  }
}
