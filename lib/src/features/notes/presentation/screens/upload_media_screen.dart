import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers.dart';
import '../../domain/note_entity.dart';
import '../../providers.dart';

class UploadMediaScreen extends ConsumerStatefulWidget {
  const UploadMediaScreen({super.key, this.initialFilePath});

  /// Pre-selects a file — used when the screen is opened via a share intent.
  final String? initialFilePath;

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
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _initFromSharedFile(widget.initialFilePath!);
    }
  }

  Future<void> _initFromSharedFile(String path) async {
    final file = io.File(path);
    if (!await file.exists()) return;
    final stat = await file.stat();
    final name = path.split('/').last;
    if (!mounted) return;
    setState(() {
      _selectedFile = PlatformFile(path: path, name: name, size: stat.size);
    });
  }

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

  Future<void> _pickFromCamera() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null) return;

    final file = io.File(image.path);
    final stat = await file.stat();
    final name = image.path.split('/').last;
    if (!mounted) return;
    setState(() {
      _selectedFile = PlatformFile(
        path: image.path,
        name: name,
        size: stat.size,
      );
    });
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
      userId: ref.read(currentUserProvider)?.id ?? '',
      type: type,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : file.name,
      mediaAssets: [file.path ?? file.name],
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(notesRepositoryProvider).saveNote(note, filePath: file.path);

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Files source
        _SourceTile(
          icon: Icons.cloud_upload_rounded,
          label: 'Choose from Files',
          subtitle: 'PDF, TXT, Images, Audio, Video',
          onTap: _pickFile,
        ),
        AppSpacing.gapV16,
        // Camera source
        _SourceTile(
          icon: Icons.camera_alt_rounded,
          label: 'Take a Photo',
          subtitle: 'Capture whiteboard or document',
          onTap: _pickFromCamera,
        ),
      ],
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

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s20),
        decoration: BoxDecoration(
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.25),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            AppSpacing.gapH16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
