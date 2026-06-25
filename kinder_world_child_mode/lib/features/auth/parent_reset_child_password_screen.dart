import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/api/api_providers.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/utils/color_compat.dart';
import 'package:kinder_world/core/widgets/auth_widgets.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/features/auth/widgets/child_login_picture_password_picker.dart';
import 'package:kinder_world/routing/route_paths.dart';

/// Screen opened from the password-reset link emailed to a parent. It lets the
/// parent choose a new picture password for their child without logging in,
/// using only the one-time token embedded in the link.
class ParentResetChildPasswordScreen extends ConsumerStatefulWidget {
  const ParentResetChildPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ParentResetChildPasswordScreen> createState() =>
      _ParentResetChildPasswordScreenState();
}

class _ParentResetChildPasswordScreenState
    extends ConsumerState<ParentResetChildPasswordScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _selectedPictures = [];

  bool _submitting = false;
  bool _done = false;
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
    _animController.dispose();
    super.dispose();
  }

  void _togglePicture(String id) {
    setState(() {
      if (_selectedPictures.contains(id)) {
        _selectedPictures.remove(id);
      } else if (_selectedPictures.length < 3) {
        _selectedPictures.add(id);
      }
    });
  }

  Future<void> _submit(AppLocalizations l10n) async {
    if (widget.token.isEmpty) {
      setState(() => _errorMessage = l10n.invalidResetToken);
      return;
    }
    if (_selectedPictures.length != 3) {
      setState(() => _errorMessage = l10n.picturePasswordNeedsThree);
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final authApi = ref.read(authApiProvider);
      await authApi.resetChildPicturePassword(
        token: widget.token,
        newPicturePassword: List<String>.from(_selectedPictures),
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
          msg = l10n.invalidResetToken;
        } else {
          msg = raw.isNotEmpty ? raw : l10n.passwordResetFailed;
        }
      } else {
        msg = l10n.connectionError;
      }
      setState(() {
        _submitting = false;
        _errorMessage = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = l10n.connectionError;
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
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => context.go(Routes.childLogin),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValuesCompat(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValuesCompat(alpha: 0.25),
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
                              color: Colors.white.withValuesCompat(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    Colors.white.withValuesCompat(alpha: 0.30),
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.resetChildPasswordTitle,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  l10n.resetChildPasswordSubtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Colors.white.withValuesCompat(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.resetChildPasswordInstruction,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: auth.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          ChildLoginPicturePasswordPicker(
            l10n: l10n,
            selectedPictures: _selectedPictures,
            pictureOptions: picturePasswordOptions,
            onTogglePicture: _togglePicture,
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
            const SizedBox(height: 16),
          ],
          GradientButton(
            label: l10n.resetPassword,
            isLoading: _submitting,
            onPressed: _submitting ? null : () => _submit(l10n),
            gradientColors: [auth.brandDeep, auth.brandLight],
          ),
        ],
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
            label: l10n.backToChildLogin,
            onPressed: () => context.go(Routes.childLogin),
            gradientColors: [auth.brandDeep, auth.brandLight],
          ),
        ],
      ),
    );
  }
}
