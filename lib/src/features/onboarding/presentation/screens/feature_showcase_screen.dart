import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../providers.dart';

class FeatureShowcaseScreen extends ConsumerStatefulWidget {
  const FeatureShowcaseScreen({super.key});

  @override
  ConsumerState<FeatureShowcaseScreen> createState() =>
      _FeatureShowcaseScreenState();
}

class _FeatureShowcaseScreenState extends ConsumerState<FeatureShowcaseScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _ShowcasePage(
      icon: Icons.auto_stories_rounded,
      title: 'Learn from your notes',
      description:
          'Transform your notes, PDFs, and links into bite-sized learning '
          'articles powered by AI. Study smarter, not harder.',
    ),
    _ShowcasePage(
      icon: Icons.psychology_rounded,
      title: 'Adaptive & personalized',
      description:
          'Your feed adapts to your interests and learning pace. '
          'Spaced repetition ensures you retain what you learn.',
    ),
    _ShowcasePage(
      icon: Icons.hub_rounded,
      title: 'Connect the dots',
      description:
          'Visualize how concepts relate with an interactive knowledge graph. '
          'Ask questions and get answers grounded in your content.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _leave();
    }
  }

  void _skip() => _leave();

  /// Marks the feature showcase as seen, then navigates to login.
  /// SharedPreferences write is awaited so the router sees the updated flag
  /// when it evaluates the redirect for the next navigation.
  Future<void> _leave() async {
    await ref.read(onboardingRepositoryProvider).completeShowcase();
    if (mounted) context.go('/${RouteNames.login}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.s16,
                  right: AppSpacing.s16,
                ),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: context.textTheme.labelLarge?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page);
                },
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s16,
                AppSpacing.s24,
                AppSpacing.s48,
              ),
              child: Column(
                children: [_buildDots(), AppSpacing.gapV32, _buildNextButton()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_ShowcasePage page) {
    return Padding(
      padding: AppSpacing.paddingH24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 48, color: AppColors.primary),
          ),
          AppSpacing.gapV32,
          Text(
            page.title,
            style: context.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapV16,
          Text(
            page.description,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        );
      }),
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentPage == _pages.length - 1;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _nextPage,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
          backgroundColor: AppColors.primary,
        ),
        child: Text(
          isLast ? 'Get Started' : 'Next',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}

class _ShowcasePage {
  const _ShowcasePage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
