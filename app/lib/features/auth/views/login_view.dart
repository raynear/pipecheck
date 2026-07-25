import 'package:boilerplate/core/services/snackbar_service.dart';
import 'package:boilerplate/core/widgets/buttons/adaptive_button.dart';
import 'package:boilerplate/core/widgets/common/semantics.dart';
import 'package:boilerplate/core/widgets/navigation/adaptive_app_bar.dart';
import 'package:boilerplate/features/auth/view_models/auth_view_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utils/utils.dart';

/// 이메일/비밀번호 로그인 화면
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authViewModel = ref.read(authViewModelProvider.notifier);
      final snackbar = ref.read(snackBarServiceProvider);

      AuthResult result;
      if (_isSignUp) {
        result = await authViewModel.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        result = await authViewModel.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      if (result.isSuccess) {
        if (result.requiresEmailVerification) {
          // 키 전달 — SnackBarService가 .tr() 해석. result.message도 키(auth.*).
          snackbar.showSuccess(result.message ?? 'login.emailVerificationRequired');
        } else {
          snackbar.showSuccess(_isSignUp ? 'login.signUpComplete' : 'login.signInSuccess');
          context.go('/home');
        }
      } else {
        snackbar.showError(result.message ?? 'errors.generic');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ref.read(snackBarServiceProvider).showError('login.enterEmail');
      return;
    }

    if (Validators.email(email) != null) {
      ref.read(snackBarServiceProvider).showError('login.enterValidEmail');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(authViewModelProvider.notifier)
          .sendPasswordResetEmail(email: email);

      if (!mounted) return;

      if (result.isSuccess) {
        ref.read(snackBarServiceProvider).showSuccess(
              result.message ?? 'auth.passwordResetSent',
            );
      } else {
        ref.read(snackBarServiceProvider).showError(
              result.message ?? 'auth.emailSendFailed',
            );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: SText(_isSignUp ? 'login.signUp' : 'login.signIn'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // 로고 또는 앱 아이콘
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),

                // 타이틀
                Text(
                  _isSignUp ? 'login.createAccountTitle'.tr() : 'login.welcomeTitle'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  _isSignUp ? 'login.signUpSubtitle'.tr() : 'login.signInSubtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // 이메일 필드
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'login.emailLabel'.tr(),
                    hintText: 'example@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) => Validators.combine(value, [
                    Validators.required,
                    Validators.email,
                  ]),
                ),
                const SizedBox(height: 16),

                // 비밀번호 필드
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction:
                      _isSignUp ? TextInputAction.next : TextInputAction.done,
                  onFieldSubmitted: _isSignUp ? null : (_) => _handleSubmit(),
                  decoration: InputDecoration(
                    labelText: 'login.passwordLabel'.tr(),
                    hintText: 'login.passwordHint'.tr(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: _isSignUp
                      ? (value) => Validators.password(
                            value,
                            minLength: 6,
                            requireUppercase: false,
                            requireNumber: false,
                          )
                      : Validators.required,
                ),

                // 비밀번호 확인 (회원가입 시)
                if (_isSignUp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                    decoration: InputDecoration(
                      labelText: 'login.confirmPasswordLabel'.tr(),
                      hintText: 'login.confirmPasswordHint'.tr(),
                      prefixIcon: const Icon(Icons.lock_outlined),
                    ),
                    validator:
                        Validators.confirmPassword(_passwordController.text),
                  ),
                ],

                const SizedBox(height: 24),

                // 로그인/회원가입 버튼
                AdaptiveButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  label: '',
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : SText(_isSignUp ? 'login.signUp' : 'login.signIn'),
                ),

                // 비밀번호 찾기 (로그인 시)
                if (!_isSignUp) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _handlePasswordReset,
                    child: SText('login.forgotPassword'),
                  ),
                ],

                const SizedBox(height: 24),

                // 구분선
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SText('login.or',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 24),

                // 모드 전환 버튼
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _confirmPasswordController.clear();
                          });
                        },
                  child: SText(_isSignUp ? 'login.switchToSignIn' : 'login.switchToSignUp'),
                ),

                const SizedBox(height: 16),

                // 뒤로가기 (게스트로 계속)
                TextButton(
                  onPressed: _isLoading ? null : () => context.go('/home'),
                  child: SText('login.continueAsGuest'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
