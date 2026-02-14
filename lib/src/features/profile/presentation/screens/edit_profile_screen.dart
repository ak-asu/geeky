import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late List<String> _interests;
  late List<String> _goals;
  final _goalController = TextEditingController();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _interests = List<String>.from(user?.interests ?? []);
    _goals = List<String>.from(user?.goals ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final updated = user.copyWith(
      name: _nameController.text.trim(),
      interests: _interests,
      goals: _goals,
    );

    await ref.read(authProvider.notifier).updateUser(updated);

    if (mounted) {
      context.showSnackBar('Profile updated');
      context.pop();
    }
  }

  void _addGoal() {
    final text = _goalController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _goals.add(text);
      _goalController.clear();
    });
    _markChanged();
  }

  void _removeGoal(int index) {
    setState(() => _goals.removeAt(index));
    _markChanged();
  }

  void _removeInterest(String interest) {
    setState(() => _interests.remove(interest));
    _markChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _hasChanges ? _save : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _hasChanges ? AppColors.primary : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // Name
          Text(
            'Display Name',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV8,
          TextField(
            controller: _nameController,
            onChanged: (_) => _markChanged(),
            decoration: InputDecoration(
              hintText: 'Your name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              contentPadding: AppSpacing.paddingV8H16,
            ),
          ),

          AppSpacing.gapV24,

          // Email (read-only)
          Text(
            'Email',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV8,
          TextField(
            controller: _emailController,
            enabled: false,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              contentPadding: AppSpacing.paddingV8H16,
              fillColor: context.colorScheme.surfaceContainerHighest,
              filled: true,
            ),
          ),

          AppSpacing.gapV24,

          // Interests
          Text(
            'Interests',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV8,
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: _interests.map((interest) {
              return Chip(
                label: Text(interest),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeInterest(interest),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                side: BorderSide.none,
              );
            }).toList(),
          ),

          AppSpacing.gapV24,

          // Goals
          Text(
            'Learning Goals',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV8,
          ..._goals.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                  AppSpacing.gapH8,
                  Expanded(
                    child: Text(
                      entry.value,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: AppColors.error.withValues(alpha: 0.6),
                    ),
                    onPressed: () => _removeGoal(entry.key),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapV8,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _goalController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addGoal(),
                  decoration: InputDecoration(
                    hintText: 'Add a goal...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    contentPadding: AppSpacing.paddingV8H16,
                  ),
                ),
              ),
              AppSpacing.gapH8,
              IconButton.filled(
                onPressed: _addGoal,
                icon: const Icon(Icons.add_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          AppSpacing.gapV48,
        ],
      ),
    );
  }
}
