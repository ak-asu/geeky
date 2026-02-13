import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/note_entity.dart';
import '../../providers.dart';

class CreateNoteScreen extends ConsumerStatefulWidget {
  const CreateNoteScreen({super.key});

  @override
  ConsumerState<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends ConsumerState<CreateNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _saving = false;

  static const _uuid = Uuid();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final content = _contentController.text.trim();
    final wordCount = content
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final now = DateTime.now();

    final note = NoteEntity(
      id: _uuid.v4(),
      userId: 'mock-user',
      type: 'text',
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
      content: content,
      wordCount: wordCount,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(notesRepositoryProvider).saveNote(note);

    if (mounted) {
      context.showSnackBar('Note saved');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Note'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingAll16,
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Title (optional)',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(height: AppSpacing.s24),

            // Content
            TextFormField(
              controller: _contentController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              minLines: 12,
              validator: (v) => Validators.required(v, 'Content'),
              style: context.textTheme.bodyLarge?.copyWith(height: 1.7),
              decoration: const InputDecoration(
                hintText: 'Start typing your note...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
