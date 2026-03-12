import 'package:flutter/material.dart';

Color _onColor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : const Color(0xFF111827);
}

Color _surfaceBlend(Color surface, Color tint, double alpha) {
  return Color.alphaBlend(tint.withValues(alpha: alpha), surface);
}

class ThemePalette {
  const ThemePalette({
    required this.id,
    required this.name,
    required this.seedColor,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightSurfaceContainer,
    required this.lightOutline,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkSurfaceContainer,
    required this.darkOutline,
    required this.previewColors,
  });

  final String id;
  final String name;
  final Color seedColor;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color lightBackground;
  final Color lightSurface;
  final Color lightSurfaceContainer;
  final Color lightOutline;
  final Color darkBackground;
  final Color darkSurface;
  final Color darkSurfaceContainer;
  final Color darkOutline;
  final List<Color> previewColors;

  ColorScheme colorScheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? darkSurface : lightSurface;
    final background = isDark ? darkBackground : lightBackground;
    final surfaceContainer =
        isDark ? darkSurfaceContainer : lightSurfaceContainer;
    final outline = isDark ? darkOutline : lightOutline;

    final primaryContainer = _surfaceBlend(
      surface,
      primary,
      isDark ? 0.28 : 0.16,
    );
    final secondaryContainer = _surfaceBlend(
      surface,
      secondary,
      isDark ? 0.24 : 0.14,
    );
    final tertiaryContainer = _surfaceBlend(
      surface,
      tertiary,
      isDark ? 0.24 : 0.14,
    );
    final surfaceLow = _surfaceBlend(
      surface,
      isDark ? Colors.white : primary,
      isDark ? 0.05 : 0.03,
    );
    final surfaceBase = _surfaceBlend(
      surface,
      primary,
      isDark ? 0.08 : 0.05,
    );
    final surfaceHigh = _surfaceBlend(
      surface,
      secondary,
      isDark ? 0.12 : 0.07,
    );

    return base.copyWith(
      primary: primary,
      onPrimary: _onColor(primary),
      primaryContainer: primaryContainer,
      onPrimaryContainer: _onColor(primaryContainer),
      secondary: secondary,
      onSecondary: _onColor(secondary),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: _onColor(secondaryContainer),
      tertiary: tertiary,
      onTertiary: _onColor(tertiary),
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: _onColor(tertiaryContainer),
      surface: surface,
      onSurface: isDark ? const Color(0xFFF2F6FB) : const Color(0xFF111827),
      surfaceContainerLowest: background,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceBase,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceContainer,
      onSurfaceVariant:
          isDark ? const Color(0xFFC7D1DD) : const Color(0xFF5B6675),
      outline: outline,
      outlineVariant: outline.withValues(alpha: isDark ? 0.78 : 0.58),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface:
          isDark ? const Color(0xFFF7FAFE) : const Color(0xFF182432),
      onInverseSurface:
          isDark ? const Color(0xFF16212D) : const Color(0xFFF5F8FC),
      inversePrimary: base.inversePrimary,
    );
  }
}

class ThemePalettes {
  ThemePalettes._();

  static const String defaultPaletteId = 'default';

  static const ThemePalette defaultPalette = ThemePalette(
    id: defaultPaletteId,
    name: 'Skyline',
    seedColor: Color(0xFF2F6FED),
    primary: Color(0xFF2F6FED),
    secondary: Color(0xFF00A6A6),
    tertiary: Color(0xFF8B5CF6),
    lightBackground: Color(0xFFF4F8FF),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceContainer: Color(0xFFE7EEFF),
    lightOutline: Color(0xFF8FA2C4),
    darkBackground: Color(0xFF08121F),
    darkSurface: Color(0xFF111D2D),
    darkSurfaceContainer: Color(0xFF1C2B40),
    darkOutline: Color(0xFF6D84A7),
    previewColors: <Color>[
      Color(0xFF2F6FED),
      Color(0xFF00A6A6),
      Color(0xFF8B5CF6),
    ],
  );

  static const ThemePalette purple = ThemePalette(
    id: 'purple',
    name: 'Aurora',
    seedColor: Color(0xFF7B61FF),
    primary: Color(0xFF7B61FF),
    secondary: Color(0xFFFF6BAA),
    tertiary: Color(0xFF00B4D8),
    lightBackground: Color(0xFFF8F5FF),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceContainer: Color(0xFFEEE7FF),
    lightOutline: Color(0xFFA895D9),
    darkBackground: Color(0xFF120D20),
    darkSurface: Color(0xFF1C1630),
    darkSurfaceContainer: Color(0xFF2A2144),
    darkOutline: Color(0xFF7F74A8),
    previewColors: <Color>[
      Color(0xFF7B61FF),
      Color(0xFFFF6BAA),
      Color(0xFF00B4D8),
    ],
  );

  static const ThemePalette green = ThemePalette(
    id: 'green',
    name: 'Canopy',
    seedColor: Color(0xFF1F8F5F),
    primary: Color(0xFF1F8F5F),
    secondary: Color(0xFFF7B538),
    tertiary: Color(0xFF2E6FD8),
    lightBackground: Color(0xFFF3FBF7),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceContainer: Color(0xFFE1F3E9),
    lightOutline: Color(0xFF8EAE9E),
    darkBackground: Color(0xFF0B1712),
    darkSurface: Color(0xFF12231B),
    darkSurfaceContainer: Color(0xFF1D3327),
    darkOutline: Color(0xFF6F8D7B),
    previewColors: <Color>[
      Color(0xFF1F8F5F),
      Color(0xFFF7B538),
      Color(0xFF2E6FD8),
    ],
  );

  static const ThemePalette sunset = ThemePalette(
    id: 'sunset',
    name: 'Sunset',
    seedColor: Color(0xFFFF6B4A),
    primary: Color(0xFFFF6B4A),
    secondary: Color(0xFFFFB347),
    tertiary: Color(0xFFEF476F),
    lightBackground: Color(0xFFFFF5EF),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceContainer: Color(0xFFFFE6DA),
    lightOutline: Color(0xFFC79A8C),
    darkBackground: Color(0xFF1D0F0B),
    darkSurface: Color(0xFF281711),
    darkSurfaceContainer: Color(0xFF39231A),
    darkOutline: Color(0xFF9E7565),
    previewColors: <Color>[
      Color(0xFFFF6B4A),
      Color(0xFFFFB347),
      Color(0xFFEF476F),
    ],
  );

  // Legacy aliases kept for stored preferences and tests.
  static const ThemePalette blue = ThemePalette(
    id: 'blue',
    name: 'Ocean Blue',
    seedColor: Color(0xFF2F6FED),
    primary: Color(0xFF2F6FED),
    secondary: Color(0xFF00A6A6),
    tertiary: Color(0xFF8B5CF6),
    lightBackground: Color(0xFFF4F8FF),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceContainer: Color(0xFFE7EEFF),
    lightOutline: Color(0xFF8FA2C4),
    darkBackground: Color(0xFF08121F),
    darkSurface: Color(0xFF111D2D),
    darkSurfaceContainer: Color(0xFF1C2B40),
    darkOutline: Color(0xFF6D84A7),
    previewColors: <Color>[
      Color(0xFF2F6FED),
      Color(0xFF00A6A6),
      Color(0xFF8B5CF6),
    ],
  );

  static const ThemePalette pastel = ThemePalette(
    id: 'pastel',
    name: 'Pastel Dream',
    seedColor: Color(0xFF7B61FF),
    primary: Color(0xFF7B61FF),
    secondary: Color(0xFFFF6BAA),
    tertiary: Color(0xFF00B4D8),
    lightBackground: Color(0xFFF8F5FF),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceContainer: Color(0xFFEEE7FF),
    lightOutline: Color(0xFFA895D9),
    darkBackground: Color(0xFF120D20),
    darkSurface: Color(0xFF1C1630),
    darkSurfaceContainer: Color(0xFF2A2144),
    darkOutline: Color(0xFF7F74A8),
    previewColors: <Color>[
      Color(0xFF7B61FF),
      Color(0xFFFF6BAA),
      Color(0xFF00B4D8),
    ],
  );

  static const List<ThemePalette> all = <ThemePalette>[
    defaultPalette,
    purple,
    green,
    sunset,
  ];

  static ThemePalette byId(String id) {
    switch (id) {
      case 'blue':
        return defaultPalette;
      case 'pastel':
        return purple;
      default:
        return all.firstWhere(
          (palette) => palette.id == id,
          orElse: () => defaultPalette,
        );
    }
  }
}
