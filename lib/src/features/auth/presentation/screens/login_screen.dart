import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../routing/route_names.dart';
import '../../providers.dart';
import '../widgets/social_login_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) context.showSnackBar('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingH24,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSpacing.gapV48,
                    _buildHeader(),
                    AppSpacing.gapV48,
                    _buildEmailField(),
                    AppSpacing.gapV16,
                    _buildPasswordField(),
                    AppSpacing.gapV8,
                    _buildForgotPassword(),
                    AppSpacing.gapV24,
                    _buildLoginButton(),
                    AppSpacing.gapV24,
                    _buildDivider(),
                    AppSpacing.gapV24,
                    _buildSocialLogin(),
                    AppSpacing.gapV32,
                    _buildSignupLink(),
                    AppSpacing.gapV48,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        AppSpacing.gapV24,
        Text(
          'Welcome back',
          style: context.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        AppSpacing.gapV8,
        Text(
          'Sign in to continue learning',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      validator: Validators.email,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
        prefixIcon: Icon(Icons.email_outlined),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      validator: Validators.password,
      onFieldSubmitted: (_) => _handleLogin(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          context.showSnackBar('Password reset coming soon');
        },
        child: Text(
          'Forgot password?',
          style: context.textTheme.bodySmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return FilledButton(
      onPressed: _loading ? null : _handleLogin,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        backgroundColor: AppColors.primary,
      ),
      child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Sign In',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: AppSpacing.paddingH16,
          child: Text(
            'or',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSocialLogin() {
    return SocialLoginButton(
      icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
      label: 'Continue with Google',
      onPressed: _loading ? null : _handleGoogleSignIn,
    );
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: () => context.go('/${RouteNames.signup}'),
          child: Text(
            'Sign Up',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
