import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/messages/app_messages.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/utils/color_compat.dart';
import 'package:kinder_world/core/widgets/auth_widgets.dart';
import 'package:kinder_world/routing/route_paths.dart';

class ParentResetPasswordScreen extends ConsumerStatefulWidget {
  const ParentResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ParentResetPasswordScreen> createState() =>
      _ParentResetPasswordScreenState();
}

class _ParentResetPasswordScreenState
    extends ConsumerState<ParentResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  bool _done = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final authApi = ref.read(authApiProvider);
      await authApi.resetPassword(
        token: widget.token,
        newPassword: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });
      _animController.reset();
      unawaited(_animController.forward());
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data;
      String msg;
      if (detail is Map) {
        final raw = detail['detail']?.toString() ?? '';
        if (e.response?.statusCode == 400 &&
            (raw.toLowerCase().contains('invalid') ||
                raw.toLowerCase().contains('expired'))) {
          msg = AppLocalizations.of(context)!.invalidResetToken;
        } else {
          msg = raw.isNotEmpty
              ? raw
              : AppLocalizations.of(context)!.passwordResetFailed;
        }
      } else {
        msg = AppLocalizations.of(context)!.connectionError;
      }
      setState(() {
        _submitting = false;
        _errorMessage = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = AppLocalizations.of(context)!.connectionError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final auth = context.authTheme;

    return Scaffold(
      backgroundColor: auth.pageBackground,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [auth.brandDeep, auth.brand, auth.brandLight],
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValuesCompat(alpha: 0.07),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => context.go(Routes.parentLogin),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValuesCompat(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white
                                      .withValuesCompat(alpha: 0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValuesCompat(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white
                                        .withValuesCompat(alpha: 0.30),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.resetPassword,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    l10n.parentAccount,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white
                                          .withValuesCompat(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: screenHeight * 0.26,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SafeArea(
                  top: false,
                  child: _done ? _buildSuccess(l10n) : _buildForm(l10n),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    final auth = context.authTheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createNewPassword,
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: auth.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.forgotPasswordDescription,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: auth.textMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            AuthInputField(
              controller: _passwordController,
              label: l10n.newPasswordLabel,
              hint: l10n.newPasswordHint,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: auth.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.newPasswordRequired;
                }
                if (value.length < 8) {
                  return AuthUiMessages.passwordMinLength;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthInputField(
              controller: _confirmPasswordController,
              label: l10n.confirmNewPasswordLabel,
              hint: l10n.confirmNewPasswordHint,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: auth.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.confirmNewPasswordRequired;
                }
                if (value != _passwordController.text) {
                  return l10n.passwordsDoNotMatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValuesCompat(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.withValuesCompat(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage == l10n.invalidResetToken) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.resetLinkExpiredMessage,
                  style: TextStyle(fontSize: 12, color: auth.textMuted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(Routes.parentForgotPassword),
                  child: Text(l10n.sendResetLink),
                ),
              ],
              const SizedBox(height: 8),
            ],
            GradientButton(
              label: l10n.resetPassword,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
              gradientColors: [auth.brandDeep, auth.brandLight],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(AppLocalizations l10n) {
    final auth = context.authTheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.successColor.withValuesCompat(alpha: 0.10),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 60,
              color: context.successColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.passwordResetSuccess,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: auth.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.passwordResetSuccessSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: auth.textMuted,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GradientButton(
            label: l10n.goToLogin,
            onPressed: () => context.go(Routes.parentLogin),
            gradientColors: [auth.brandDeep, auth.brandLight],
          ),
        ],
      ),
    );
  }
}
