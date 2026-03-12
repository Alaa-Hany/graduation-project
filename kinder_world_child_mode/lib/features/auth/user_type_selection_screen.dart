import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/navigation/app_navigation_controller.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/theme/theme_extensions.dart';
import 'package:kinder_world/router.dart';

class UserTypeSelectionScreen extends ConsumerStatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  ConsumerState<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState
    extends ConsumerState<UserTypeSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _panelsController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _parentFade;
  late Animation<Offset> _parentSlide;
  late Animation<double> _childFade;
  late Animation<Offset> _childSlide;

  String? _pressedPanel;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _panelsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    ));

    _parentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _panelsController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );
    _parentSlide = Tween<Offset>(
      begin: const Offset(-0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelsController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    ));

    _childFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _panelsController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );
    _childSlide = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelsController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _headerController.forward();
      _panelsController.forward();
    });
    Future<void>.microtask(() async {
      try {
        final secureStorage = ref.read(secureStorageProvider);
        if (secureStorage.hasCachedParentPinVerification &&
            !secureStorage.cachedSessionSnapshot.parentPinVerified) {
          return;
        }
        await secureStorage.clearParentPinVerification();
      } catch (_) {
        // Some isolated widget tests render this screen without app-level overrides.
      }
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _panelsController.dispose();
    super.dispose();
  }

  Future<void> _selectUserType(String userType) async {
    if (_pressedPanel != null) {
      return;
    }
    setState(() => _pressedPanel = userType);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;

    final secureStorage = ref.read(secureStorageProvider);
    final authToken = secureStorage.hasCachedSessionSnapshot
        ? secureStorage.cachedSessionSnapshot.authToken
        : await secureStorage.getAuthToken();
    final userRole = secureStorage.hasCachedSessionSnapshot
        ? secureStorage.cachedSessionSnapshot.userRole
        : await secureStorage.getUserRole();
    final childSession = userType == 'child'
        ? (secureStorage.hasCachedSessionSnapshot
            ? secureStorage.cachedSessionSnapshot.childSession
            : await secureStorage.getChildSession())
        : null;

    if (!mounted) return;

    final isAuthenticated = authToken != null && authToken.isNotEmpty;
    if (userType == 'parent') {
      context.go(
        isAuthenticated && userRole == 'parent'
            ? Routes.parentDashboard
            : Routes.parentLogin,
      );
      return;
    }

    context.go(
      isAuthenticated && userRole == 'child' && childSession != null
          ? Routes.childHome
          : Routes.childLogin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.authTheme;
    final textTheme = context.text;
    final childTheme = context.childTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final container = ProviderScope.containerOf(context, listen: false);
        await container
            .read(appNavigationControllerProvider)
            .handleSystemBack(context);
      },
      child: Scaffold(
        backgroundColor: auth.pageBackground,
        body: SafeArea(
          child: Column(
          children: [
            // ── Header ──
            FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    children: [
                      // Back button row
                      Row(
                        children: [
                          _CircleBackButton(
                            onTap: () => context.appBack(fallback: Routes.welcome),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.whoIsUsingKinderWorld,
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: auth.textPrimary,
                          letterSpacing: -0.8,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.selectUserTypeSubtitle,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: auth.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Role panels ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // Parent panel
                    Expanded(
                      child: FadeTransition(
                        opacity: _parentFade,
                        child: SlideTransition(
                          position: _parentSlide,
                          child: _RolePanel(
                            title: l10n.parentMode,
                            description: l10n.parentModeDescription,
                            icon: Icons.shield_rounded,
                            secondaryIcon: Icons.bar_chart_rounded,
                            tertiaryIcon: Icons.family_restroom_rounded,
                            gradientColors: [
                              auth.brandDeep,
                              auth.brand,
                              auth.brandLight,
                            ],
                            accentColor: auth.brandLight,
                            tag: l10n.secureAndStructured,
                            tagIcon: Icons.verified_rounded,
                            isPressed: _pressedPanel == 'parent',
                            onTap: () => _selectUserType('parent'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Child panel
                    Expanded(
                      child: FadeTransition(
                        opacity: _childFade,
                        child: SlideTransition(
                          position: _childSlide,
                          child: _RolePanel(
                            title: l10n.childMode,
                            description: l10n.childModeDescription,
                            icon: Icons.auto_awesome_rounded,
                            secondaryIcon: Icons.sports_esports_rounded,
                            tertiaryIcon: Icons.emoji_events_rounded,
                            gradientColors: [
                              childTheme.kindness,
                              auth.child,
                              auth.childLight,
                            ],
                            accentColor: auth.childBackground,
                            tag: l10n.funAndPlayful,
                            tagIcon: Icons.star_rounded,
                            isPressed: _pressedPanel == 'child',
                            onTap: () => _selectUserType('child'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => context.go(Routes.adminLogin),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Admin',
                          style: textTheme.bodySmall?.copyWith(
                            color: auth.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
// _RolePanel — dramatic gradient panel for each role
// ─────────────────────────────────────────────────────────────────────────────
class _RolePanel extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final IconData secondaryIcon;
  final IconData tertiaryIcon;
  final List<Color> gradientColors;
  final Color accentColor;
  final String tag;
  final IconData tagIcon;
  final bool isPressed;
  final VoidCallback onTap;

  const _RolePanel({
    required this.title,
    required this.description,
    required this.icon,
    required this.secondaryIcon,
    required this.tertiaryIcon,
    required this.gradientColors,
    required this.accentColor,
    required this.tag,
    required this.tagIcon,
    required this.isPressed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.40),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // ── Decorative circles ──
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
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
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // ── Floating secondary icons ──
              Positioned(
                top: 16,
                right: 60,
                child: Icon(
                  secondaryIcon,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 24,
                child: Icon(
                  tertiaryIcon,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),

              // ── Main content ──
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Icon area
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 36, color: Colors.white),
                    ),
                    const SizedBox(width: 20),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tag badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tagIcon,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.9)),
                                const SizedBox(width: 4),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.80),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Arrow
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
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
// _CircleBackButton
// ─────────────────────────────────────────────────────────────────────────────
class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final auth = context.authTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: auth.inputBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: auth.textMuted,
        ),
      ),
    );
  }
}
