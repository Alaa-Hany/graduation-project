import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/auth_error_localizer.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/messages/app_messages.dart';
import 'package:kinder_world/core/providers/auth_controller.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/utils/email_validation.dart';
import 'package:kinder_world/core/widgets/auth_widgets.dart';
import 'package:kinder_world/routing/route_paths.dart';

class ParentVerifyEmailScreen extends ConsumerStatefulWidget {
  const ParentVerifyEmailScreen({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  ConsumerState<ParentVerifyEmailScreen> createState() =>
      _ParentVerifyEmailScreenState();
}

class _ParentVerifyEmailScreenState
    extends ConsumerState<ParentVerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();
  Timer? _timer;
  Duration _remainingCooldown = Duration.zero;

  @override
  void initState() {
    super.initState();
    final pendingEmail =
        ref.read(authControllerProvider).pendingVerificationEmail;
    _emailController = TextEditingController(
      text: widget.initialEmail ?? pendingEmail ?? '',
    );
    _syncCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _syncCooldown() {
    _timer?.cancel();
    final resendAvailableAt =
        ref.read(authControllerProvider).resendAvailableAt;
    if (resendAvailableAt == null) {
      setState(() => _remainingCooldown = Duration.zero);
      return;
    }

    void tick() {
      final remaining = resendAvailableAt.difference(DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _remainingCooldown = remaining.isNegative ? Duration.zero : remaining;
      });
      if (_remainingCooldown == Duration.zero) {
        _timer?.cancel();
      }
    }

    tick();
    if (_remainingCooldown > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.verifyParentEmailOtp(
      email: _emailController.text.trim().toLowerCase(),
      otp: _otpController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email verified successfully.'),
          backgroundColor: context.successColor,
        ),
      );
      context.go(Routes.parentDashboard);
      return;
    }

    _syncCooldown();
    final error = ref.read(authControllerProvider).error;
    _showMessage(error ?? AuthUiMessages.verificationCodeInvalid);
  }

  Future<void> _resendOtp() async {
    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.resendParentEmailOtp(
      email: _emailController.text.trim().toLowerCase(),
    );

    if (!mounted) {
      return;
    }

    _syncCooldown();
    final message = ref.read(authControllerProvider).error;
    _showMessage(
      message ??
          (success
              ? AuthUiMessages.verificationCodeResent
              : AuthUiMessages.registrationFailedTryAgain),
      isError: !success,
    );
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizeAuthErrorMessage(
            message,
            AppLocalizations.of(context)!,
          ),
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : context.successColor,
      ),
    );
  }

  String _cooldownLabel() {
    final seconds = _remainingCooldown.inSeconds;
    if (seconds <= 0) {
      return 'Resend code';
    }
    return 'Resend in ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final canResend = _remainingCooldown == Duration.zero && !isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the 6-digit code we sent to your email.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account will be activated after successful verification.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                AuthInputField(
                  controller: _emailController,
                  label: l10n.email,
                  hint: l10n.emailHint,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.emailRequired;
                    }
                    if (!isValidEmailFormat(value)) {
                      return l10n.invalidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthInputField(
                  controller: _otpController,
                  label: 'Verification code',
                  hint: '123456',
                  prefixIcon: Icons.verified_user_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final normalized = (value ?? '').trim();
                    if (normalized.length != 6 ||
                        int.tryParse(normalized) == null) {
                      return 'Enter the 6-digit code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Verify Email',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _verifyOtp,
                  gradientColors: [
                    context.authTheme.brandDeep,
                    context.authTheme.brandLight,
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: canResend ? _resendOtp : null,
                    child: Text(_cooldownLabel()),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(Routes.parentLogin),
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
