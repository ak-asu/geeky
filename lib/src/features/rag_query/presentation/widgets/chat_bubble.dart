import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/markdown_renderer.dart';
import '../../domain/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: context.screenWidth * 0.85),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: _isUser
              ? AppColors.primary
              : context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusLg),
            topRight: const Radius.circular(AppSpacing.radiusLg),
            bottomLeft: Radius.circular(
              _isUser ? AppSpacing.radiusLg : AppSpacing.s4,
            ),
            bottomRight: Radius.circular(
              _isUser ? AppSpacing.s4 : AppSpacing.radiusLg,
            ),
          ),
        ),
        child: _isUser
            ? Text(
                message.content,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              )
            : MarkdownRenderer(
                data: message.content,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              ),
      ),
    );
  }
}
