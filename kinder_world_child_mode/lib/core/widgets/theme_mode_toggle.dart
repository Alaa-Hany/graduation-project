// ─────────────────────────────────────────────────────────────────────────────
// DEAD CODE — ThemeModeToggle widget is not imported anywhere in the app.
// The app uses inline IconButton toggles in child_home_screen.dart instead.
// Safe to delete or adopt as a shared widget.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

class ThemeModeToggle extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  final double width;
  final double height;

  const ThemeModeToggle({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.width = 170,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platformBrightness == Brightness.dark);
    final knobAlignment = isDark ? Alignment.centerRight : Alignment.centerLeft;

    return Semantics(
      button: true,
      label: 'Theme mode toggle',
      value: isDark ? 'Dark' : 'Light',
      child: Directionality(
        textDirection: Directionality.of(context),
        child: GestureDetector(
          onTap: () {
            onModeChanged(isDark ? ThemeMode.light : ThemeMode.dark);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: width,
            height: height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(
                color: colors.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          Icons.wb_sunny_outlined,
                          size: 18,
                          color: isDark ? colors.onSurfaceVariant : colors.onSurface,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          Icons.nights_stay_outlined,
                          size: 18,
                          color: isDark ? colors.onSurface : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  alignment: knobAlignment,
                  child: Container(
                    width: height - 8,
                    height: height - 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
