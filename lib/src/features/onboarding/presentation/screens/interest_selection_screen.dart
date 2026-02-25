import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../../auth/providers.dart';
import '../../providers.dart';

/// Interest selection screen used in two modes:
///
/// **First-run** (`isEditing = false`, default):
///   Shown automatically after sign-up when `onboardingCompleted` is false.
///   Saving marks onboarding complete and navigates to the app.
///
/// **Edit** (`isEditing = true`):
///   Reached from profile via `context.push(..., extra: true)`.
///   Saving updates the user profile and pops back to profile.
class InterestSelectionScreen extends ConsumerStatefulWidget {
  const InterestSelectionScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  ConsumerState<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState
    extends ConsumerState<InterestSelectionScreen> {
  final _searchController = TextEditingController();
  late final Set<String> _selected;
  String _query = '';
  bool _saving = false;

  static const _availableTopics = [
    'Artificial Intelligence',
    'Machine Learning',
    'Deep Learning',
    'Natural Language Processing',
    'Computer Vision',
    'Web Development',
    'Mobile Development',
    'Cloud Computing',
    'Data Science',
    'Data Engineering',
    'Statistics',
    'Mathematics',
    'Linear Algebra',
    'Calculus',
    'Probability',
    'Algorithms',
    'Data Structures',
    'System Design',
    'Databases',
    'Cognitive Psychology',
    'Neuroscience',
    'Philosophy',
    'Physics',
    'Chemistry',
    'Biology',
    'Economics',
    'History',
    'Literature',
    'Cybersecurity',
    'DevOps',
    'Blockchain',
    'Quantum Computing',
  ];

  List<String> get _filteredTopics {
    if (_query.isEmpty) return _availableTopics;
    final lower = _query.toLowerCase();
    return _availableTopics
        .where((t) => t.toLowerCase().contains(lower))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      // Pre-populate with the user's existing interests from auth state.
      final existingInterests =
          ref.read(currentUserProvider)?.interests ?? const [];
      _selected = existingInterests.toSet();
    } else {
      _selected = {};
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final interests = _selected.toList();

      if (widget.isEditing) {
        // Edit mode: update user profile (auth state + backend + local cache).
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          await ref
              .read(authProvider.notifier)
              .updateUser(currentUser.copyWith(interests: interests));
        }
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Interests updated')));
        }
      } else {
        // First-run mode: update user profile + mark onboarding complete.
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          await ref
              .read(authProvider.notifier)
              .updateUser(currentUser.copyWith(interests: interests));
        }
        // Mark onboarding done locally + best-effort backend sync.
        await ref.read(onboardingStateProvider.notifier).complete();
        if (mounted) context.go('/');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(
              title: const Text('Edit Interests'),
              leading: BackButton(onPressed: () => context.pop()),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header (first-run only) ──────────────────────────────────
            if (!widget.isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s24,
                  AppSpacing.s32,
                  AppSpacing.s24,
                  AppSpacing.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What interests you?',
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.gapV8,
                    Text(
                      'Pick a few topics to personalise your feed. '
                      'You can change these later in your profile.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Search ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s16,
                AppSpacing.s24,
                0,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search topics…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            AppSpacing.gapV12,

            // ── Selection count ──────────────────────────────────────────
            if (_selected.isNotEmpty)
              Padding(
                padding: AppSpacing.paddingH24,
                child: Text(
                  '${_selected.length} selected',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            AppSpacing.gapV8,

            // ── Topic chips ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.paddingH24,
                child: Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: _filteredTopics.map((topic) {
                    final isSelected = _selected.contains(topic);
                    return TopicChip(
                      label: topic,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(topic);
                          } else {
                            _selected.add(topic);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Action button(s) ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s16,
                AppSpacing.s24,
                AppSpacing.s32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s16,
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.isEditing
                                ? 'Save'
                                : (_selected.isEmpty
                                      ? 'Skip for now'
                                      : 'Continue'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  // "Skip for now" secondary link — first-run only
                  if (!widget.isEditing && _selected.isNotEmpty) ...[
                    AppSpacing.gapV8,
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              _selected.clear();
                              _save();
                            },
                      child: Text(
                        'Skip for now',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
