import 'package:flutter/material.dart';

@immutable
class AuthThemeTokens extends ThemeExtension<AuthThemeTokens> {
  final Color brand;
  final Color brandDeep;
  final Color brandLight;
  final Color parent;
  final Color parentLight;
  final Color parentBackground;
  final Color child;
  final Color childLight;
  final Color childBackground;
  final Color inputBackground;
  final Color inputBorder;
  final Color textPrimary;
  final Color textMuted;
  final Color textHint;
  final Color divider;
  final Color pageBackground;

  const AuthThemeTokens({
    required this.brand,
    required this.brandDeep,
    required this.brandLight,
    required this.parent,
    required this.parentLight,
    required this.parentBackground,
    required this.child,
    required this.childLight,
    required this.childBackground,
    required this.inputBackground,
    required this.inputBorder,
    required this.textPrimary,
    required this.textMuted,
    required this.textHint,
    required this.divider,
    required this.pageBackground,
  });

  factory AuthThemeTokens.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return AuthThemeTokens(
      brand: scheme.primary,
      brandDeep: Color.lerp(scheme.primary, scheme.inverseSurface, isDark ? 0.15 : 0.35)!,
      brandLight: Color.lerp(scheme.primary, Colors.white, isDark ? 0.12 : 0.28)!,
      parent: const Color(0xFF2E7D32),
      parentLight: const Color(0xFF66BB6A),
      parentBackground: isDark
          ? const Color(0xFF2E7D32).withValues(alpha: 0.20)
          : const Color(0xFFE8F5E9),
      child: const Color(0xFFE64A19),
      childLight: const Color(0xFFFF7043),
      childBackground: isDark
          ? const Color(0xFFE64A19).withValues(alpha: 0.20)
          : const Color(0xFFFBE9E7),
      inputBackground: isDark
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
          : const Color(0xFFF8F9FB),
      inputBorder: isDark ? scheme.outline : const Color(0xFFE2E8F0),
      textPrimary: scheme.onSurface,
      textMuted: scheme.onSurfaceVariant,
      textHint: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      divider: isDark ? scheme.outlineVariant : const Color(0xFFE8ECF4),
      pageBackground: isDark ? scheme.surface : const Color(0xFFF7F9FC),
    );
  }

  @override
  AuthThemeTokens copyWith({
    Color? brand,
    Color? brandDeep,
    Color? brandLight,
    Color? parent,
    Color? parentLight,
    Color? parentBackground,
    Color? child,
    Color? childLight,
    Color? childBackground,
    Color? inputBackground,
    Color? inputBorder,
    Color? textPrimary,
    Color? textMuted,
    Color? textHint,
    Color? divider,
    Color? pageBackground,
  }) {
    return AuthThemeTokens(
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      brandLight: brandLight ?? this.brandLight,
      parent: parent ?? this.parent,
      parentLight: parentLight ?? this.parentLight,
      parentBackground: parentBackground ?? this.parentBackground,
      child: child ?? this.child,
      childLight: childLight ?? this.childLight,
      childBackground: childBackground ?? this.childBackground,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textHint: textHint ?? this.textHint,
      divider: divider ?? this.divider,
      pageBackground: pageBackground ?? this.pageBackground,
    );
  }

  @override
  AuthThemeTokens lerp(ThemeExtension<AuthThemeTokens>? other, double t) {
    if (other is! AuthThemeTokens) return this;
    return AuthThemeTokens(
      brand: Color.lerp(brand, other.brand, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      brandLight: Color.lerp(brandLight, other.brandLight, t)!,
      parent: Color.lerp(parent, other.parent, t)!,
      parentLight: Color.lerp(parentLight, other.parentLight, t)!,
      parentBackground: Color.lerp(parentBackground, other.parentBackground, t)!,
      child: Color.lerp(child, other.child, t)!,
      childLight: Color.lerp(childLight, other.childLight, t)!,
      childBackground: Color.lerp(childBackground, other.childBackground, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
    );
  }
}

@immutable
class ParentThemeTokens extends ThemeExtension<ParentThemeTokens> {
  final Color primary;
  final Color primaryLight;
  final Color alert;
  final Color warning;
  final Color info;
  final Color accent;
  final Color reward;
  final Color streak;
  final Color divider;

  const ParentThemeTokens({
    required this.primary,
    required this.primaryLight,
    required this.alert,
    required this.warning,
    required this.info,
    required this.accent,
    required this.reward,
    required this.streak,
    required this.divider,
  });

  factory ParentThemeTokens.fromScheme(ColorScheme scheme) {
    return ParentThemeTokens(
      primary: scheme.primary,
      primaryLight: scheme.primaryContainer,
      alert: scheme.error,
      warning: const Color(0xFFF57F17),
      info: scheme.tertiary,
      accent: scheme.secondary,
      reward: const Color(0xFFFFB300),
      streak: const Color(0xFFE64A19),
      divider: scheme.outlineVariant,
    );
  }

  @override
  ParentThemeTokens copyWith({
    Color? primary,
    Color? primaryLight,
    Color? alert,
    Color? warning,
    Color? info,
    Color? accent,
    Color? reward,
    Color? streak,
    Color? divider,
  }) {
    return ParentThemeTokens(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      alert: alert ?? this.alert,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      accent: accent ?? this.accent,
      reward: reward ?? this.reward,
      streak: streak ?? this.streak,
      divider: divider ?? this.divider,
    );
  }

  @override
  ParentThemeTokens lerp(ThemeExtension<ParentThemeTokens>? other, double t) {
    if (other is! ParentThemeTokens) return this;
    return ParentThemeTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      reward: Color.lerp(reward, other.reward, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

@immutable
class ChildThemeTokens extends ThemeExtension<ChildThemeTokens> {
  final Color xp;
  final Color streak;
  final Color streakLight;
  final Color success;
  final Color kindness;
  final Color learning;
  final Color skill;
  final Color fun;
  final Color buddyStart;
  final Color buddyEnd;

  const ChildThemeTokens({
    required this.xp,
    required this.streak,
    required this.streakLight,
    required this.success,
    required this.kindness,
    required this.learning,
    required this.skill,
    required this.fun,
    required this.buddyStart,
    required this.buddyEnd,
  });

  factory ChildThemeTokens.fromScheme(ColorScheme scheme) {
    return ChildThemeTokens(
      xp: const Color(0xFFFFD700),
      streak: const Color(0xFFFF6B35),
      streakLight: const Color(0xFFFF9800),
      success: const Color(0xFF4CAF50),
      kindness: const Color(0xFFE91E63),
      learning: scheme.primary,
      skill: const Color(0xFF9C27B0),
      fun: const Color(0xFF00BCD4),
      buddyStart: Color.lerp(scheme.primary, scheme.secondary, 0.45)!,
      buddyEnd: Color.lerp(scheme.primary, scheme.tertiary, 0.55)!,
    );
  }

  @override
  ChildThemeTokens copyWith({
    Color? xp,
    Color? streak,
    Color? streakLight,
    Color? success,
    Color? kindness,
    Color? learning,
    Color? skill,
    Color? fun,
    Color? buddyStart,
    Color? buddyEnd,
  }) {
    return ChildThemeTokens(
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      streakLight: streakLight ?? this.streakLight,
      success: success ?? this.success,
      kindness: kindness ?? this.kindness,
      learning: learning ?? this.learning,
      skill: skill ?? this.skill,
      fun: fun ?? this.fun,
      buddyStart: buddyStart ?? this.buddyStart,
      buddyEnd: buddyEnd ?? this.buddyEnd,
    );
  }

  @override
  ChildThemeTokens lerp(ThemeExtension<ChildThemeTokens>? other, double t) {
    if (other is! ChildThemeTokens) return this;
    return ChildThemeTokens(
      xp: Color.lerp(xp, other.xp, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      streakLight: Color.lerp(streakLight, other.streakLight, t)!,
      success: Color.lerp(success, other.success, t)!,
      kindness: Color.lerp(kindness, other.kindness, t)!,
      learning: Color.lerp(learning, other.learning, t)!,
      skill: Color.lerp(skill, other.skill, t)!,
      fun: Color.lerp(fun, other.fun, t)!,
      buddyStart: Color.lerp(buddyStart, other.buddyStart, t)!,
      buddyEnd: Color.lerp(buddyEnd, other.buddyEnd, t)!,
    );
  }
}

extension ThemeDataX on ThemeData {
  AuthThemeTokens get auth => extension<AuthThemeTokens>()!;
  ParentThemeTokens get parentTokens => extension<ParentThemeTokens>()!;
  ChildThemeTokens get childTokens => extension<ChildThemeTokens>()!;
}

extension BuildContextThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get text => theme.textTheme;
  AuthThemeTokens get authTheme => theme.auth;
  ParentThemeTokens get parentTheme => theme.parentTokens;
  ChildThemeTokens get childTheme => theme.childTokens;

  Color get successColor => childTheme.success;
  Color get warningColor => parentTheme.warning;
  Color get infoColor => parentTheme.info;
  Color get rewardColor => parentTheme.reward;
  Color get subtleSurface => colors.surfaceContainerHighest;
}

extension ThemeColorX on Color {
  Color subtle([double alpha = 0.12]) => withValues(alpha: alpha);
}
