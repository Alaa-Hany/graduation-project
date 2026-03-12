import 'package:flutter/material.dart';

Color _onColor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : const Color(0xFF111827);
}

Color _mix(Color a, Color b, double t) {
  return Color.lerp(a, b, t)!;
}

@immutable
class AuthThemeTokens extends ThemeExtension<AuthThemeTokens> {
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
    final parent = scheme.primary;
    final child = _mix(scheme.secondary, scheme.tertiary, 0.35);
    return AuthThemeTokens(
      brand: scheme.primary,
      brandDeep: _mix(scheme.primary, scheme.inverseSurface, isDark ? 0.24 : 0.38),
      brandLight: _mix(scheme.primary, scheme.secondary, isDark ? 0.22 : 0.40),
      parent: parent,
      parentLight: _mix(parent, scheme.primaryContainer, 0.55),
      parentBackground: scheme.primaryContainer.withValues(alpha: isDark ? 0.38 : 0.82),
      child: child,
      childLight: _mix(child, scheme.tertiaryContainer, 0.45),
      childBackground: scheme.secondaryContainer.withValues(alpha: isDark ? 0.34 : 0.76),
      inputBackground: isDark
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      inputBorder: isDark
          ? scheme.outlineVariant.withValues(alpha: 0.92)
          : scheme.outlineVariant,
      textPrimary: scheme.onSurface,
      textMuted: scheme.onSurfaceVariant,
      textHint: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      divider: scheme.outlineVariant.withValues(alpha: isDark ? 0.92 : 0.72),
      pageBackground: isDark ? scheme.surface : scheme.surfaceContainerLowest,
    );
  }

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
  const ParentThemeTokens({
    required this.primary,
    required this.primaryLight,
    required this.warning,
    required this.warningLight,
    required this.info,
    required this.infoLight,
    required this.reward,
    required this.rewardLight,
    required this.success,
    required this.successLight,
    required this.danger,
    required this.dangerLight,
    required this.cardSurface,
    required this.sectionHeader,
    required this.divider,
  });

  factory ParentThemeTokens.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final warning = _mix(const Color(0xFFF59E0B), scheme.secondary, 0.28);
    final info = _mix(scheme.primary, scheme.tertiary, 0.28);
    final reward = _mix(const Color(0xFFF6C445), scheme.secondary, 0.18);
    final success = _mix(const Color(0xFF22C55E), scheme.primary, 0.18);
    final danger = _mix(const Color(0xFFEF4444), scheme.error, 0.38);
    return ParentThemeTokens(
      primary: scheme.primary,
      primaryLight: scheme.primaryContainer.withValues(alpha: isDark ? 0.42 : 0.92),
      warning: warning,
      warningLight: warning.withValues(alpha: isDark ? 0.22 : 0.14),
      info: info,
      infoLight: info.withValues(alpha: isDark ? 0.22 : 0.14),
      reward: reward,
      rewardLight: reward.withValues(alpha: isDark ? 0.24 : 0.14),
      success: success,
      successLight: success.withValues(alpha: isDark ? 0.24 : 0.14),
      danger: danger,
      dangerLight: danger.withValues(alpha: isDark ? 0.24 : 0.14),
      cardSurface: scheme.surfaceContainerLow,
      sectionHeader: scheme.onSurfaceVariant,
      divider: scheme.outlineVariant.withValues(alpha: isDark ? 0.88 : 0.72),
    );
  }

  final Color primary;
  final Color primaryLight;
  final Color warning;
  final Color warningLight;
  final Color info;
  final Color infoLight;
  final Color reward;
  final Color rewardLight;
  final Color success;
  final Color successLight;
  final Color danger;
  final Color dangerLight;
  final Color cardSurface;
  final Color sectionHeader;
  final Color divider;

  Color get alert => danger;

  @override
  ParentThemeTokens copyWith({
    Color? primary,
    Color? primaryLight,
    Color? warning,
    Color? warningLight,
    Color? info,
    Color? infoLight,
    Color? reward,
    Color? rewardLight,
    Color? success,
    Color? successLight,
    Color? danger,
    Color? dangerLight,
    Color? cardSurface,
    Color? sectionHeader,
    Color? divider,
  }) {
    return ParentThemeTokens(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      warning: warning ?? this.warning,
      warningLight: warningLight ?? this.warningLight,
      info: info ?? this.info,
      infoLight: infoLight ?? this.infoLight,
      reward: reward ?? this.reward,
      rewardLight: rewardLight ?? this.rewardLight,
      success: success ?? this.success,
      successLight: successLight ?? this.successLight,
      danger: danger ?? this.danger,
      dangerLight: dangerLight ?? this.dangerLight,
      cardSurface: cardSurface ?? this.cardSurface,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      divider: divider ?? this.divider,
    );
  }

  @override
  ParentThemeTokens lerp(ThemeExtension<ParentThemeTokens>? other, double t) {
    if (other is! ParentThemeTokens) return this;
    return ParentThemeTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoLight: Color.lerp(infoLight, other.infoLight, t)!,
      reward: Color.lerp(reward, other.reward, t)!,
      rewardLight: Color.lerp(rewardLight, other.rewardLight, t)!,
      success: Color.lerp(success, other.success, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerLight: Color.lerp(dangerLight, other.dangerLight, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      sectionHeader: Color.lerp(sectionHeader, other.sectionHeader, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

@immutable
class ChildThemeTokens extends ThemeExtension<ChildThemeTokens> {
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
    final isDark = scheme.brightness == Brightness.dark;
    final xp = _mix(const Color(0xFFF4C542), scheme.secondary, 0.15);
    final streak = _mix(const Color(0xFFFF6B35), scheme.primary, 0.16);
    final learning = _mix(scheme.primary, scheme.secondary, 0.16);
    final skill = _mix(scheme.tertiary, scheme.primary, 0.28);
    final kindness = _mix(const Color(0xFFE94E9E), scheme.primary, 0.18);
    final fun = _mix(const Color(0xFF13B9D5), scheme.secondary, 0.18);
    final success = _mix(const Color(0xFF34C759), scheme.primary, 0.12);
    return ChildThemeTokens(
      xp: xp,
      streak: streak,
      streakLight: streak.withValues(alpha: isDark ? 0.28 : 0.16),
      success: success,
      kindness: kindness,
      learning: learning,
      skill: skill,
      fun: fun,
      buddyStart: _mix(scheme.primary, scheme.secondary, 0.45),
      buddyEnd: _mix(scheme.secondary, scheme.tertiary, 0.40),
    );
  }

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

extension ThemeDataThemeX on ThemeData {
  AuthThemeTokens get auth =>
      extension<AuthThemeTokens>() ?? AuthThemeTokens.fromScheme(colorScheme);

  ParentThemeTokens get parentTokens =>
      extension<ParentThemeTokens>() ?? ParentThemeTokens.fromScheme(colorScheme);

  ChildThemeTokens get childTokens =>
      extension<ChildThemeTokens>() ?? ChildThemeTokens.fromScheme(colorScheme);
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

  Color get onColor => _onColor(this);
}
