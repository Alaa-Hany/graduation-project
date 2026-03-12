import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/core/widgets/auth_widgets.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Hero Header ──
          FadeTransition(
            opacity: _heroFade,
            child: SlideTransition(
              position: _heroSlide,
              child: _HeroHeader(screenHeight: size.height),
            ),
          ),

          // ── Scrollable content ──
          Expanded(
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        l10n.welcomeTitle,
                        style: textTheme.headlineMedium?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: colors.onSurface,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.welcomeSubtitle,
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Feature grid
                      _FeatureGrid(l10n: l10n),
                      const SizedBox(height: 32),

                      // Get Started button
                      GradientButton(
                        label: l10n.getStarted,
                        onPressed: () => context.push('/select-user-type'),
                        gradientColors: [
                          colors.primary,
                          Color.lerp(colors.primary, colors.secondary, 0.45)!,
                        ],
                        height: 58,
                        icon: Icon(
                          Icons.rocket_launch_rounded,
                          color: colors.onPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Login link
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/parent/login'),
                          child: RichText(
                            text: TextSpan(
                              style: textTheme.bodyMedium?.copyWith(fontSize: 14),
                              children: [
                                TextSpan(
                                  text: l10n.alreadyHaveAccount,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                TextSpan(
                                  text: l10n.login,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // COPPA note
                      Center(
                        child: Text(
                          l10n.coppaGdprNote,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header — gradient area with logo + tagline
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final double screenHeight;
  const _HeroHeader({required this.screenHeight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final headerHeight = screenHeight * 0.30;
    final gradientColors = [
      colors.primary,
      Color.lerp(colors.primary, colors.secondary, 0.35)!,
      Color.lerp(colors.primary, colors.tertiary, 0.5)!,
    ];

    return Container(
      height: headerHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.onPrimary.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.onPrimary.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo container
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icons/kinderworld-logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.child_care_rounded,
                          size: 44,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: colors.onPrimary,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: colors.shadow.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.splashTagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onPrimary.withValues(alpha: 0.85),
                      letterSpacing: 1.5,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature Grid — 2×2 cards
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureGrid extends StatelessWidget {
  final AppLocalizations l10n;
  const _FeatureGrid({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final childTheme = context.childTheme;
    final features = [
      _FeatureItem(
        icon: Icons.school_rounded,
        label: l10n.educational,
        description: l10n.interactiveLessons,
        color: colors.primary,
        gradientColors: [
          colors.primary,
          Color.lerp(colors.primary, colors.tertiary, 0.35)!,
        ],
      ),
      _FeatureItem(
        icon: Icons.sports_esports_rounded,
        label: l10n.funGames,
        description: l10n.learnThroughPlay,
        color: childTheme.fun,
        gradientColors: [
          childTheme.fun,
          Color.lerp(childTheme.fun, colors.secondary, 0.45)!,
        ],
      ),
      _FeatureItem(
        icon: Icons.psychology_rounded,
        label: l10n.aiPowered,
        description: l10n.personalizedForChild,
        color: childTheme.kindness,
        gradientColors: [
          childTheme.kindness,
          Color.lerp(childTheme.kindness, colors.tertiary, 0.35)!,
        ],
      ),
      _FeatureItem(
        icon: Icons.shield_rounded,
        label: l10n.safe,
        description: l10n.coppaGdprCompliant,
        color: childTheme.success,
        gradientColors: [
          childTheme.success,
          Color.lerp(childTheme.success, colors.primary, 0.35)!,
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: compact ? 132 : 122,
          ),
          itemBuilder: (context, index) => _FeatureCard(
            item: features[index],
            compact: compact,
          ),
        );
      },
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final List<Color> gradientColors;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.gradientColors,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  final bool compact;
  const _FeatureCard({required this.item, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final iconColor =
        ThemeData.estimateBrightnessForColor(item.gradientColors.first) ==
                Brightness.dark
            ? colors.onPrimary
            : colors.onSurface;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 10 : 12,
        compact ? 12 : 14,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.color.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: compact ? 42 : 44,
            height: compact ? 42 : 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: item.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(item.icon, size: compact ? 20 : 22, color: iconColor),
          ),
          SizedBox(height: compact ? 10 : 10),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: item.color,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: compact ? 9.8 : 10.5,
              color: colors.onSurfaceVariant,
              height: 1.22,
            ),
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
