import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for each onboarding page
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final List<Color> decorColors;
  final IconData decorIcon1;
  final IconData decorIcon2;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.decorColors,
    required this.decorIcon1,
    required this.decorIcon2,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingScreen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));
    _contentController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  List<_OnboardingData> _pages(AppLocalizations l10n) => [
        _OnboardingData(
          title: l10n.learn,
          subtitle: l10n.onboardingLearnSubtitle,
          description: l10n.onboardingLearnDescription,
          icon: Icons.auto_stories_rounded,
          gradientColors: const [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)],
          decorColors: const [Color(0xFF90CAF9), Color(0xFFBBDEFB)],
          decorIcon1: Icons.star_rounded,
          decorIcon2: Icons.lightbulb_rounded,
        ),
        _OnboardingData(
          title: l10n.play,
          subtitle: l10n.onboardingPlaySubtitle,
          description: l10n.onboardingPlayDescription,
          icon: Icons.sports_esports_rounded,
          gradientColors: const [Color(0xFF6A1B9A), Color(0xFF8E24AA), Color(0xFFAB47BC)],
          decorColors: const [Color(0xFFCE93D8), Color(0xFFE1BEE7)],
          decorIcon1: Icons.emoji_events_rounded,
          decorIcon2: Icons.celebration_rounded,
        ),
        _OnboardingData(
          title: l10n.onboardingGrow,
          subtitle: l10n.onboardingGrowSubtitle,
          description: l10n.onboardingGrowDescription,
          icon: Icons.psychology_rounded,
          gradientColors: const [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          decorColors: const [Color(0xFFA5D6A7), Color(0xFFC8E6C9)],
          decorIcon1: Icons.trending_up_rounded,
          decorIcon2: Icons.workspace_premium_rounded,
        ),
      ];

  void _nextPage() {
    final pages = _pages(AppLocalizations.of(context)!);
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go(Routes.welcome);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _contentController.reset();
    _contentController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _pages(l10n);
    final page = pages[_currentPage];
    final isLast = _currentPage == pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated full-screen gradient background ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: page.gradientColors,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Decorative large circle top-right ──
          Positioned(
            top: -60,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),

          // ── Decorative medium circle bottom-left ──
          Positioned(
            bottom: 200,
            left: -50,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          // ── Decorative small circle mid-right ──
          Positioned(
            top: 180,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),

          // ── Floating decor icons ──
          Positioned(
            top: 120,
            left: 30,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                page.decorIcon1,
                key: ValueKey('d1_$_currentPage'),
                size: 28,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: 50,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                page.decorIcon2,
                key: ValueKey('d2_$_currentPage'),
                size: 22,
                color: Colors.white.withValues(alpha: 0.20),
              ),
            ),
          ),

          // ── PageView (visual area) ──
          PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) =>
                _OnboardingPageView(data: pages[index]),
          ),

          // ── Top bar: page indicator + skip ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page indicator
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: pages.length,
                      effect: ExpandingDotsEffect(
                        activeDotColor: Colors.white,
                        dotColor: Colors.white.withValues(alpha: 0.35),
                        dotHeight: 8,
                        dotWidth: 8,
                        expansionFactor: 3,
                        spacing: 5,
                      ),
                    ),
                    // Skip button
                    TextButton(
                      onPressed: () => context.go(Routes.welcome),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: Text(
                        l10n.skip,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom CTA panel ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: SafeArea(
                top: false,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subtitle
                        Text(
                          pages[_currentPage].subtitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Description
                        Text(
                          pages[_currentPage].description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // CTA button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  page.gradientColors.first,
                                  page.gradientColors.last,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: page.gradientColors.first
                                      .withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _nextPage,
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isLast ? l10n.getStarted : l10n.next,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isLast
                                            ? Icons.rocket_launch_rounded
                                            : Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
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
// _OnboardingPageView — the visual focus area for each page
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingPageView extends StatefulWidget {
  final _OnboardingData data;
  const _OnboardingPageView({required this.data});

  @override
  State<_OnboardingPageView> createState() => _OnboardingPageViewState();
}

class _OnboardingPageViewState extends State<_OnboardingPageView>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 70, bottom: 260),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Main icon in layered circles ──
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    // Middle ring
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Inner icon container
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.data.icon,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // ── Title ──
            FadeTransition(
              opacity: _fade,
              child: Text(
                widget.data.title,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -2.0,
                  height: 1.0,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
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
}
