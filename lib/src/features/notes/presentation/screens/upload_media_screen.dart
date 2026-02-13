import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/note_entity.dart';
import '../../providers.dart';

class UploadMediaScreen extends ConsumerStatefulWidget {
  const UploadMediaScreen({super.key});

  @override
  ConsumerState<UploadMediaScreen> createState() => _UploadMediaScreenState();
}

class _UploadMediaScreenState extends ConsumerState<UploadMediaScreen> {
  final _titleController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _saving = false;

  static const _uuid = Uuid();

  static const _allowedExtensions = [
    'pdf',
    'txt',
    'md',
    'png',
    'jpg',
    'jpeg',
    'mp3',
    'wav',
    'mp4',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _save() async {
    if (_selectedFile == null) {
      context.showSnackBar('Please select a file first');
      return;
    }

    setState(() => _saving = true);

    final file = _selectedFile!;
    final type = _inferType(file.extension ?? '');
    final now = DateTime.now();

    final note = NoteEntity(
      id: _uuid.v4(),
      userId: 'mock-user',
      type: type,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : file.name,
      mediaAssets: [file.path ?? file.name],
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(notesRepositoryProvider).saveNote(note);

    if (mounted) {
      context.showSnackBar('File uploaded as note');
      context.pop();
    }
  }

  String _inferType(String extension) {
    return switch (extension.toLowerCase()) {
      'pdf' => 'pdf',
      'txt' || 'md' => 'text',
      'png' || 'jpg' || 'jpeg' => 'image',
      'mp3' || 'wav' => 'audio',
      'mp4' => 'video',
      _ => 'text',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Media'),
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
      body: Padding(
        padding: AppSpacing.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'Give your upload a name',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            AppSpacing.gapV24,

            // File picker area
            Expanded(
              child: _selectedFile != null
                  ? _buildSelectedFile(context)
                  : _buildPickerArea(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerArea(BuildContext context) {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
              AppSpacing.gapV16,
              Text(
                'Tap to select a file',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.gapV8,
              Text(
                'PDF, TXT, Images, Audio, Video',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFile(BuildContext context) {
    final file = _selectedFile!;
    final sizeKB = (file.size / 1024).toStringAsFixed(1);

    return Column(
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              _fileIcon(file.extension ?? ''),
              color: AppColors.primary,
            ),
            title: Text(
              file.name,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('$sizeKB KB'),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _selectedFile = null),
            ),
          ),
        ),
        AppSpacing.gapV16,
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Choose different file'),
        ),
      ],
    );
  }

  IconData _fileIcon(String extension) {
    return switch (extension.toLowerCase()) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'txt' || 'md' => Icons.text_snippet_rounded,
      'png' || 'jpg' || 'jpeg' => Icons.image_rounded,
      'mp3' || 'wav' => Icons.audiotrack_rounded,
      'mp4' => Icons.videocam_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }
}
