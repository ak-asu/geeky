import 'package:flutter/material.dart';

import '../../../../core/widgets/side_action_rail.dart';

class ShortActionRail extends StatelessWidget {
  const ShortActionRail({
    super.key,
    required this.isDone,
    required this.isBookmarked,
    required this.onDone,
    required this.onBookmark,
    this.onShare,
    this.onDiveDeeper,
    this.onGoUp,
    this.onRelated,
    this.onFeedback,
    this.onTts,
  });

  final bool isDone;
  final bool isBookmarked;
  final VoidCallback onDone;
  final VoidCallback onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onDiveDeeper;
  final VoidCallback? onGoUp;
  final VoidCallback? onRelated;
  final VoidCallback? onFeedback;
  final VoidCallback? onTts;

  @override
  Widget build(BuildContext context) {
    return SideActionRail(
      primaryActions: [
        RailAction(
          icon: isDone ? Icons.check_circle_rounded : Icons.check_rounded,
          activeIcon: Icons.check_circle_rounded,
          isActive: isDone,
          label: 'Done',
          onTap: onDone,
        ),
        RailAction(
          icon: isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
          isActive: isBookmarked,
          label: 'Save',
          onTap: onBookmark,
        ),
      ],
      expandedActions: [
        if (onShare != null)
          RailAction(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: onShare!,
          ),
        if (onDiveDeeper != null)
          RailAction(
            icon: Icons.arrow_downward_rounded,
            label: 'Deeper',
            onTap: onDiveDeeper!,
          ),
        if (onGoUp != null)
          RailAction(
            icon: Icons.arrow_upward_rounded,
            label: 'Go Up',
            onTap: onGoUp!,
          ),
        if (onRelated != null)
          RailAction(
            icon: Icons.hub_rounded,
            label: 'Related',
            onTap: onRelated!,
          ),
        if (onFeedback != null)
          RailAction(
            icon: Icons.feedback_rounded,
            label: 'Feedback',
            onTap: onFeedback!,
          ),
        if (onTts != null)
          RailAction(
            icon: Icons.volume_up_rounded,
            label: 'Listen',
            onTap: onTts!,
          ),
      ],
    );
  }
}
