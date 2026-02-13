import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../providers.dart';

class InterestSelectionScreen extends ConsumerStatefulWidget {
  const InterestSelectionScreen({super.key});

  @override
  ConsumerState<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState
    extends ConsumerState<InterestSelectionScreen> {
  final _searchController = TextEditingController();
  final _selected = <String>{};
  String _query = '';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    await ref.read(selectedInterestsProvider.notifier).save(_selected.toList());
    await ref.read(onboardingStateProvider.notifier).complete();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
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
                    'Pick a few topics to personalize your feed. '
                    'You can change these later.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: AppSpacing.paddingH24,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search topics...',
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
            AppSpacing.gapV16,

            // Selected count
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

            // Topic chips
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

            // Continue button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s16,
                AppSpacing.s24,
                AppSpacing.s32,
              ),
              child: FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                  backgroundColor: AppColors.primary,
                ),
                child: Text(
                  _selected.isEmpty ? 'Skip for now' : 'Continue',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
