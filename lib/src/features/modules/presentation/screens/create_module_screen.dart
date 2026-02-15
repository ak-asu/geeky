import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers.dart';
import '../../domain/module_entity.dart';
import '../../providers.dart';
import '../../../shorts/domain/short_entity.dart';
import '../../../shorts/providers.dart';

class CreateModuleScreen extends ConsumerStatefulWidget {
  const CreateModuleScreen({super.key});

  @override
  ConsumerState<CreateModuleScreen> createState() => _CreateModuleScreenState();
}

class _CreateModuleScreenState extends ConsumerState<CreateModuleScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedTopics = <String>{};

  static const _availableTopics = [
    'AI',
    'Web Dev',
    'Data Science',
    'Mathematics',
    'Cognitive Psychology',
    'Neural Networks',
    'CSS',
    'React',
    'Python',
    'Statistics',
    'Linear Algebra',
    'Graph Theory',
    'Learning',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Finds shorts whose topics overlap with the selected module topics.
  List<String> _matchShortsByTopics(List<ShortEntity> allShorts) {
    if (_selectedTopics.isEmpty) return [];
    final lowerTopics = _selectedTopics.map((t) => t.toLowerCase()).toSet();
    return allShorts
        .where(
          (s) => s.topics.any((t) => lowerTopics.contains(t.toLowerCase())),
        )
        .map((s) => s.id)
        .toList();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showSnackBar('Please enter a module name');
      return;
    }

    // Auto-populate shortIds from topic-matched shorts
    final allShorts = ref.read(allShortsProvider).value ?? <ShortEntity>[];
    final matchedIds = _matchShortsByTopics(allShorts);

    final now = DateTime.now();
    final module = ModuleEntity(
      id: const Uuid().v4(),
      userId: ref.read(currentUserProvider)?.id ?? 'anonymous',
      name: name,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      topics: _selectedTopics.toList(),
      shortIds: matchedIds,
      totalShorts: matchedIds.length,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(modulesRepositoryProvider).saveModule(module);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Module'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Module Name',
              hintText: 'e.g. AI Fundamentals',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          AppSpacing.gapV16,

          // Description field
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'What will this module cover?',
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
          ),
          AppSpacing.gapV24,

          // Topic selection
          Text(
            'Topics',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV8,
          Text(
            'Select topics to include in this module.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapV12,
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: _availableTopics.map((topic) {
              final selected = _selectedTopics.contains(topic);
              return FilterChip(
                label: Text(topic),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedTopics.add(topic);
                    } else {
                      _selectedTopics.remove(topic);
                    }
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),

          // Matched shorts preview
          if (_selectedTopics.isNotEmpty) ...[
            AppSpacing.gapV16,
            _buildMatchPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchPreview() {
    final allShorts = ref.watch(allShortsProvider).value ?? <ShortEntity>[];
    final matchedIds = _matchShortsByTopics(allShorts);
    final count = matchedIds.length;

    return Container(
      padding: AppSpacing.paddingV8H16,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: 16,
            color: count > 0
                ? AppColors.primary
                : context.colorScheme.onSurfaceVariant,
          ),
          AppSpacing.gapH8,
          Text(
            count > 0
                ? '$count short${count == 1 ? '' : 's'} matched'
                : 'No shorts match selected topics',
            style: context.textTheme.bodySmall?.copyWith(
              color: count > 0
                  ? AppColors.primary
                  : context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
