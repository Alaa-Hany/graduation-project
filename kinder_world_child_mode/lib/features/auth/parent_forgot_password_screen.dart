import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/app_colors.dart';
import 'package:kinder_world/core/widgets/auth_widgets.dart';

class ParentForgotPasswordScreen extends StatefulWidget {
  const ParentForgotPasswordScreen({super.key});

  @override
  State<ParentForgotPasswordScreen> createState() =>
      _ParentForgotPasswordScreenState();
}

class _ParentForgotPasswordScreenState extends State<ParentForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

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
    _emailController.dispose();
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

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });

    _animController
      ..reset()
      ..forward();
  }

  void _resetState() {
    setState(() {
      _sent = false;
      _emailController.clear();
    });
    _animController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.28,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1565C0),
                    Color(0xFF1976D2),
                    Color(0xFF42A5F5),
                  ],
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(36)),
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
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -10,
                    left: -10,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
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
                            onTap: () => context.go('/parent/login'),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
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
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.30),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
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
                  child:
                      _sent ? _buildSuccessState(l10n) : _buildFormState(l10n),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.forgotYourPassword,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.forgotPasswordDescription,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            AuthInputField(
              controller: _emailController,
              label: l10n.emailAddress,
              hint: l10n.emailPlaceholder,
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.emailValidationEmpty;
                }
                if (!_isAllowedEmail(value)) {
                  return l10n.emailValidationInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.spamFolderNote,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: l10n.sendResetLink,
              isLoading: _sending,
              onPressed: _sending ? null : _sendReset,
              gradientColors: const [
                Color(0xFF1565C0),
                Color(0xFF42A5F5),
              ],
              icon: _sending
                  ? null
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => context.go('/parent/login'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.backToLogin,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight > 52 ? constraints.maxHeight - 52 : 0,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.10),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    size: 56,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.checkYourInbox,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.resetLinkSentTo(_emailController.text.trim()),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      _StepRow(
                        step: '1',
                        text: l10n.step1OpenEmail,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      _StepRow(
                        step: '2',
                        text: l10n.step2ClickLink,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      _StepRow(
                        step: '3',
                        text: l10n.step3CreatePassword,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: l10n.backToLogin,
                  onPressed: () => context.go('/parent/login'),
                  gradientColors: const [
                    Color(0xFF1565C0),
                    Color(0xFF42A5F5),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resetState,
                  child: Text(
                    l10n.didntReceiveIt,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.text,
    required this.color,
  });

  final String step;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
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
