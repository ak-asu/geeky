import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers.dart';
import '../../domain/chat_message.dart';
import '../../domain/rag_response.dart';
import '../../providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/citation_card.dart';
import '../widgets/follow_up_chips.dart';

class RagQueryScreen extends ConsumerStatefulWidget {
  const RagQueryScreen({super.key});

  @override
  ConsumerState<RagQueryScreen> createState() => _RagQueryScreenState();
}

class _RagQueryScreenState extends ConsumerState<RagQueryScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(ragChatProvider.notifier).ask(text);
    _scrollToBottom();
  }

  void _askFollowUp(String question) {
    _controller.text = question;
    _send();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(ragChatProvider);

    ref.listen(ragChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ask a Question',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              tooltip: 'New session',
              onPressed: () =>
                  ref.read(ragChatProvider.notifier).clearSession(),
            ),
          const SizedBox(width: AppSpacing.s4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? _EmptyState(onSuggestionTap: _askFollowUp)
                : _ChatBody(
                    scrollController: _scrollController,
                    messages: chatState.messages,
                    lastResponse: chatState.lastResponse,
                    isLoading: chatState.isLoading,
                    onFollowUpTap: _askFollowUp,
                  ),
          ),
          _InputBar(
            controller: _controller,
            isLoading: chatState.isLoading,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  List<String> _buildSuggestions(List<String>? interests) {
    if (interests == null || interests.isEmpty) {
      return [
        'What have I learned recently?',
        'Summarize my most recent notes',
        'What are my knowledge gaps?',
      ];
    }
    return interests
        .take(3)
        .map((t) => 'What have I learned about $t?')
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final suggestions = _buildSuggestions(user?.interests);

    return Center(
      child: Padding(
        padding: AppSpacing.paddingAll24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.gapV24,
            Text(
              'Ask your knowledge base',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.gapV8,
            Text(
              'Get AI-powered answers grounded in your notes and shorts.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapV24,
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) {
                return ActionChip(
                  label: Text(
                    s,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  onPressed: () => onSuggestionTap(s),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.scrollController,
    required this.messages,
    required this.lastResponse,
    required this.isLoading,
    required this.onFollowUpTap,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final RagResponse? lastResponse;
  final bool isLoading;
  final ValueChanged<String> onFollowUpTap;

  @override
  Widget build(BuildContext context) {
    final resp = lastResponse;
    final hasFollowUps =
        !isLoading && resp != null && resp.followUpQuestions.isNotEmpty;

    return ListView.builder(
      controller: scrollController,
      padding: AppSpacing.paddingAll16,
      itemCount: messages.length + (isLoading ? 1 : 0) + (hasFollowUps ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final msg = messages[index];
          final isLastAssistant =
              msg.role == MessageRole.assistant && index == messages.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChatBubble(message: msg),
              if (isLastAssistant &&
                  resp != null &&
                  resp.citations.isNotEmpty) ...[
                AppSpacing.gapV8,
                CitationCard(citations: resp.citations),
              ],
              AppSpacing.gapV8,
            ],
          );
        }

        if (isLoading && index == messages.length) {
          return const _TypingIndicator();
        }

        if (hasFollowUps) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: FollowUpChips(
              questions: resp.followUpQuestions,
              onTap: onFollowUpTap,
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s8,
        AppSpacing.s8 + context.viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: 'Ask a question...',
                hintStyle: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.colorScheme.surfaceContainerHighest,
                contentPadding: AppSpacing.paddingV8H16,
              ),
              style: context.textTheme.bodyMedium,
            ),
          ),
          AppSpacing.gapH8,
          IconButton.filled(
            onPressed: isLoading ? null : onSend,
            icon: const Icon(Icons.send_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppSpacing.radiusLg),
            topRight: Radius.circular(AppSpacing.radiusLg),
            bottomRight: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: Duration.zero),
            AppSpacing.gapH4,
            _Dot(delay: Duration(milliseconds: 200)),
            AppSpacing.gapH4,
            _Dot(delay: Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final Duration delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(
            alpha: 0.3 + _animation.value * 0.5,
          ),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
