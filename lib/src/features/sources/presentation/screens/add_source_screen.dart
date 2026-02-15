import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers.dart';
import '../../domain/content_source_entity.dart';
import '../../providers.dart';

class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key});

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  String _selectedType = 'url';

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showSnackBar('Please enter a source name');
      return;
    }

    final source = ContentSourceEntity(
      id: const Uuid().v4(),
      userId: ref.read(currentUserProvider)?.id ?? 'anonymous',
      type: _selectedType,
      name: name,
      url: _urlController.text.trim().isNotEmpty
          ? _urlController.text.trim()
          : null,
      status: 'active',
      healthScore: 1.0,
      lastChecked: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await ref.read(sourcesRepositoryProvider).addSource(source);
    ref.invalidate(allSourcesProvider);
    if (mounted) {
      context.pop();
      context.showSnackBar('Source added');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Source')),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // Type selector
          Text(
            'SOURCE TYPE',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV8,
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'url',
                label: Text('URL'),
                icon: Icon(Icons.link_rounded, size: 18),
              ),
              ButtonSegment(
                value: 'file',
                label: Text('File'),
                icon: Icon(Icons.insert_drive_file_rounded, size: 18),
              ),
            ],
            selected: {_selectedType},
            onSelectionChanged: (selected) {
              setState(() => _selectedType = selected.first);
            },
          ),

          AppSpacing.gapV24,

          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Source Name',
              hintText: 'e.g., Stanford CS229 Notes',
            ),
            textInputAction: TextInputAction.next,
          ),

          AppSpacing.gapV16,

          // URL field (shown for URL type)
          if (_selectedType == 'url')
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/resource',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),

          AppSpacing.gapV32,

          // Predefined sources grid
          Text(
            'QUICK ADD',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV8,
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: _predefinedSources.map((source) {
              return ActionChip(
                avatar: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(source['name']!),
                onPressed: () {
                  _nameController.text = source['name']!;
                  _urlController.text = source['url'] ?? '';
                  setState(() => _selectedType = 'url');
                },
              );
            }).toList(),
          ),

          AppSpacing.gapV32,

          // Save button
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: AppSpacing.paddingV16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            child: const Text('Add Source'),
          ),
        ],
      ),
    );
  }

  static const _predefinedSources = [
    {'name': 'Wikipedia', 'url': 'https://en.wikipedia.org'},
    {'name': 'Khan Academy', 'url': 'https://khanacademy.org'},
    {'name': 'MIT OCW', 'url': 'https://ocw.mit.edu'},
    {'name': 'Arxiv', 'url': 'https://arxiv.org'},
    {'name': 'MDN Web Docs', 'url': 'https://developer.mozilla.org'},
  ];
}
