import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/providers/change_password_controller.dart';
import 'package:kinder_world/router.dart';

class ParentChangePasswordScreen extends ConsumerStatefulWidget {
  const ParentChangePasswordScreen({super.key});

  @override
  ConsumerState<ParentChangePasswordScreen> createState() =>
      _ParentChangePasswordScreenState();
}

class _ParentChangePasswordScreenState
    extends ConsumerState<ParentChangePasswordScreen> {
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passwordState = ref.watch(changePasswordControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentChangePassword),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Current password field
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                labelText: l10n.currentPasswordLabel,
                hintText: l10n.currentPasswordHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _showCurrentPassword = !_showCurrentPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // New password field
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                hintText: l10n.newPasswordHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _showNewPassword = !_showNewPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm password field
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: l10n.confirmPasswordLabel,
                hintText: l10n.confirmPasswordHintAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Error message if exists
            if (passwordState.maybeWhen(
              error: (err, _) => true,
              orElse: () => false,
            ))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  border: Border.all(color: colors.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  passwordState.maybeWhen(
                    error: (err, _) => err.toString(),
                    orElse: () => '',
                  ),
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            const SizedBox(height: 16),

            // Update button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: passwordState.maybeWhen(
                  loading: () => null,
                  orElse: () => () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final successMsg = l10n.passwordUpdatedSuccess;

                    final success = await ref
                        .read(changePasswordControllerProvider.notifier)
                        .changePassword(
                          currentPassword: _currentPasswordController.text,
                          newPassword: _newPasswordController.text,
                          confirmPassword: _confirmPasswordController.text,
                        );

                    if (success && mounted) {
                      // ignore: use_build_context_synchronously
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(successMsg),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      context.go(Routes.parentSettings);
                    }
                  },
                ),
                child: passwordState.maybeWhen(
                  loading: () => SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
                    ),
                  ),
                  orElse: () => Text(l10n.updatePassword),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
