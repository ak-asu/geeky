import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_spacing.dart';

/// A pre-configured SliverAppBar that floats and snaps for immersive reading.
class AutoHideAppBar extends StatelessWidget {
  const AutoHideAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.pinned = false,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: !pinned,
      snap: !pinned,
      pinned: pinned,
      backgroundColor: context.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: leading,
      title: title,
      centerTitle: true,
      actions: [
        ...?actions,
        const SizedBox(width: AppSpacing.s8),
      ],
      bottom: bottom,
    );
  }
}
