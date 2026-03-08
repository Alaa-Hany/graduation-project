import 'package:flutter/material.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH COLOR TOKENS
// Fixed palette used across the entire pre-auth / auth flow.
// Independent of the user's chosen theme so the first-impression is consistent.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// BRAND MARK  (gradient square with rounded corners)
// ─────────────────────────────────────────────────────────────────────────────

class AuthBrandMark extends StatelessWidget {
  final double size;

  const AuthBrandMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final auth = context.authTheme;
    final textTheme = context.text;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [auth.brandDeep, auth.brand, auth.brandLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: auth.brand.withValues(alpha: 0.40),
            blurRadius: size * 0.55,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'K',
          style: textTheme.displayMedium?.copyWith(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w900,
            color: context.colors.onPrimary,
            letterSpacing: -2,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH TEXT FIELD  (label above, fully styled)
// ─────────────────────────────────────────────────────────────────────────────

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final Color? accentColor;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.authTheme;
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final resolvedAccent = accentColor ?? auth.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: auth.textMuted,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          autocorrect: autocorrect,
          enableSuggestions: false,
          enabled: enabled,
          validator: validator,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ).copyWith(color: auth.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: auth.textHint,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(prefixIcon, size: 20, color: auth.textHint),
            suffixIcon: suffix,
            fillColor: auth.inputBackground,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: auth.inputBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: resolvedAccent, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
            ),
          ).applyDefaults(theme.inputDecorationTheme),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH PRIMARY BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.text;
    final colors = context.colors;
    final resolvedColor = color ?? context.authTheme.brand;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: context.theme.filledButtonTheme.style?.copyWith(
          backgroundColor: WidgetStatePropertyAll(resolvedColor),
          foregroundColor: WidgetStatePropertyAll(colors.onPrimary),
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 54)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.onPrimary,
                ),
              )
            : Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: colors.onPrimary,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SECONDARY BUTTON (outlined)
// ─────────────────────────────────────────────────────────────────────────────

class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.text;
    final resolvedColor = color ?? context.authTheme.brand;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: context.theme.outlinedButtonTheme.style?.copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: resolvedColor, width: 1.5),
          ),
          foregroundColor: WidgetStatePropertyAll(resolvedColor),
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 54)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: resolvedColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OR DIVIDER
// ─────────────────────────────────────────────────────────────────────────────

class AuthOrDivider extends StatelessWidget {
  final String label;

  const AuthOrDivider({super.key, this.label = 'OR'});

  @override
  Widget build(BuildContext context) {
    final auth = context.authTheme;
    final textTheme = context.text;
    return Row(
      children: [
        Expanded(
          child: Divider(color: auth.divider, thickness: 1.5),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: auth.textHint,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: auth.divider, thickness: 1.5),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN HEADER  (title + subtitle block)
// ─────────────────────────────────────────────────────────────────────────────

class AuthScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.authTheme;
    final textTheme = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.displayMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: auth.textPrimary,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: auth.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDENTITY HEADER STRIP  (green for parent, orange for child)
// ─────────────────────────────────────────────────────────────────────────────

class AuthIdentityHeader extends StatelessWidget {
  final List<Color> gradientColors;
  final IconData icon;
  final String label;
  final VoidCallback onBack;

  const AuthIdentityHeader({
    super.key,
    required this.gradientColors,
    required this.icon,
    required this.label,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 20),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colors.onPrimary,
                  size: 20,
                ),
                onPressed: onBack,
              ),
              Icon(icon, color: colors.onPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.onPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASSWORD STRENGTH INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  int get _strength {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*()_+\-=\[\]{};:,.<>?]'))) score++;
    return score;
  }

  String get _label {
    switch (_strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.authTheme;
    final textTheme = context.text;
    final colors = context.colors;
    final strengthColor = switch (_strength) {
      1 => colors.error,
      2 => colors.tertiary,
      3 => colors.primary,
      4 => Color.lerp(colors.primary, colors.secondary, 0.35)!,
      _ => auth.divider,
    };
    if (password.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < _strength ? strengthColor : auth.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }),
        ),
        if (_label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _label,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: strengthColor,
            ),
          ),
        ],
      ],
    );
  }
}
