import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/auth_widgets.dart';

class ChildForgotPasswordScreen extends StatefulWidget {
  const ChildForgotPasswordScreen({super.key});

  @override
  State<ChildForgotPasswordScreen> createState() =>
      _ChildForgotPasswordScreenState();
}

class _ChildForgotPasswordScreenState extends State<ChildForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _childIdController = TextEditingController();
  final _parentEmailController = TextEditingController();

  bool _sending = false;
  bool _sent = false;

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
    _childIdController.dispose();
    _parentEmailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool _isAllowedEmail(String value) {
    final email = value.trim().toLowerCase();
    if (!email.contains('@')) return false;
    final domain = email.split('@').last;
    return domain == 'gmail.com' ||
        domain == 'outlook.com' ||
        domain == 'hotmail.com' ||
        domain == 'live.com';
  }

  Future<void> _sendHelp(AppLocalizations l10n) async {
    if (_childIdController.text.trim().isEmpty) {
      _showError(l10n.childIdRequired);
      return;
    }
    if (_parentEmailController.text.trim().isEmpty ||
        !_isAllowedEmail(_parentEmailController.text)) {
      _showError(l10n.parentEmailInvalid);
      return;
    }

    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });

    _animController.reset();
    _animController.forward();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final auth = context.authTheme;

    return Scaffold(
      backgroundColor: auth.pageBackground,
      body: Stack(
        children: [
          // ── Playful gradient header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * 0.30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    auth.child,
                    auth.childLight,
                    context.colors.tertiary,
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -35,
                    right: -35,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: -20,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 40,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          // Back button
                          GestureDetector(
                            onTap: () => context.go('/child/login'),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
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
                          // Emoji + title
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🆘',
                                    style: TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.needHelp,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    l10n.wellAskYourParent,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.80),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main content ──
          Positioned.fill(
            top: size.height * 0.27,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: _sent ? _buildSuccessState(l10n) : _buildFormState(l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form state ──
  Widget _buildFormState(AppLocalizations l10n) {
    final auth = context.authTheme;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.forgotYourPictures,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: auth.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.forgotPicturesDescription,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: auth.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // Child ID field
          AuthInputField(
            controller: _childIdController,
            label: l10n.yourChildId,
            hint: l10n.childIdHint,
            prefixIcon: Icons.badge_outlined,
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.childIdRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Parent email field
          AuthInputField(
            controller: _parentEmailController,
            label: l10n.parentsEmail,
            hint: l10n.parentEmailHint,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.parentEmailRequired;
              }
              if (!_isAllowedEmail(value)) {
                return l10n.parentEmailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: auth.childBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: auth.childLight.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.parentWillGetEmail,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: auth.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Send button
          GradientButton(
            label: l10n.askParentForHelp,
            isLoading: _sending,
            onPressed: _sending ? null : () => _sendHelp(l10n),
            gradientColors: [
              auth.child,
              auth.childLight,
            ],
            icon: _sending
                ? null
                : const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
          ),
          const SizedBox(height: 16),

          // Back to login
          Center(
            child: TextButton(
              onPressed: () => context.go('/child/login'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.backToChildLogin,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success state ──
  Widget _buildSuccessState(AppLocalizations l10n) {
    final auth = context.authTheme;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Animated success icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [auth.childBackground, auth.childLight.subtle(0.18)],
              ),
              boxShadow: [
                BoxShadow(
                  color: auth.child.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 52)),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            l10n.messageSentTitle,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: auth.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.messageSentToParent(_parentEmailController.text.trim()),
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: auth.textMuted,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // What happens next card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: auth.childLight.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: auth.child.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.whatHappensNext,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: auth.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _ChildStepRow(
                  emoji: '📧',
                  text: l10n.childStep1,
                ),
                const SizedBox(height: 10),
                _ChildStepRow(
                  emoji: '🔑',
                  text: l10n.childStep2,
                ),
                const SizedBox(height: 10),
                _ChildStepRow(
                  emoji: '🎮',
                  text: l10n.childStep3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Back to login button
          GradientButton(
            label: l10n.backToChildLogin,
            onPressed: () => context.go('/child/login'),
            gradientColors: [
              auth.child,
              auth.childLight,
            ],
          ),
          const SizedBox(height: 14),

          // Try again
          TextButton(
            onPressed: () {
              setState(() {
                _sent = false;
                _childIdController.clear();
                _parentEmailController.clear();
              });
              _animController.reset();
              _animController.forward();
            },
            child: Text(
              l10n.tryAgainDifferentInfo,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: auth.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChildStepRow — emoji step row for child success card
// ─────────────────────────────────────────────────────────────────────────────
class _ChildStepRow extends StatelessWidget {
  final String emoji;
  final String text;

  const _ChildStepRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
