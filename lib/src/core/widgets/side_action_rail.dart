import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_constants.dart';
import '../theme/app_spacing.dart';

class RailAction {
  const RailAction({
    required this.icon,
    required this.onTap,
    this.label,
    this.isActive = false,
    this.activeIcon,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool isActive;
  final IconData? activeIcon;
  final Color? activeColor;
}

class SideActionRail extends StatefulWidget {
  const SideActionRail({
    super.key,
    required this.primaryActions,
    this.expandedActions = const [],
  });

  /// Always-visible actions (max 2: e.g. Done + Bookmark)
  final List<RailAction> primaryActions;

  /// Hidden actions revealed on expand
  final List<RailAction> expandedActions;

  @override
  State<SideActionRail> createState() => _SideActionRailState();
}

class _SideActionRailState extends State<SideActionRail> {
  bool _expanded = false;
  double _opacity = 1.0;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    _startFadeTimer();
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(AppConstants.railFadeDelay, () {
      if (mounted) setState(() => _opacity = AppConstants.railFadeOpacity);
    });
  }

  void _onInteraction() {
    setState(() => _opacity = 1.0);
    _startFadeTimer();
  }

  void _toggleExpand() {
    _onInteraction();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _onInteraction,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expanded actions (shown above primary when expanded)
            if (_expanded)
              ...widget.expandedActions.map(
                (action) => _RailButton(
                  action: action,
                  colorScheme: colorScheme,
                  onTap: () {
                    _onInteraction();
                    action.onTap();
                  },
                ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3),
              ),

            // Expand chevron (only if there are expandable actions)
            if (widget.expandedActions.isNotEmpty)
              _ChevronButton(
                expanded: _expanded,
                onTap: _toggleExpand,
                colorScheme: colorScheme,
              ),

            // Primary actions (always visible)
            ...widget.primaryActions.map(
              (action) => _RailButton(
                action: action,
                colorScheme: colorScheme,
                onTap: () {
                  _onInteraction();
                  action.onTap();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.action,
    required this.colorScheme,
    required this.onTap,
  });

  final RailAction action;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = action.isActive
        ? (action.activeColor ?? colorScheme.primary)
        : colorScheme.onSurfaceVariant;
    final icon = action.isActive
        ? (action.activeIcon ?? action.icon)
        : action.icon;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon, color: color, size: 24),
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              padding: const EdgeInsets.all(AppSpacing.s12),
            ),
          ),
          if (action.label != null) ...[
            const SizedBox(height: 2),
            Text(
              action.label!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({
    required this.expanded,
    required this.onTap,
    required this.colorScheme,
  });

  final bool expanded;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: IconButton(
        icon: AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.expand_less_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        onPressed: onTap,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(AppSpacing.s8),
        ),
      ),
    );
  }
}
