import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/module_entity.dart';
import '../../providers.dart';

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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showSnackBar('Please enter a module name');
      return;
    }

    final now = DateTime.now();
    final module = ModuleEntity(
      id: const Uuid().v4(),
      userId: 'user-001',
      name: name,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      topics: _selectedTopics.toList(),
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
        title: Text(
          'Create Module',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
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
        ],
      ),
    );
  }
}
