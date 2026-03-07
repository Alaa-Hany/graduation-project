import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _navigationTimer;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _fadeController = AnimationController(
      vsync: this,
      duration: _SplashDurations.screenFadeIn,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _fadeController.forward();
    _navigationTimer = Timer(_SplashDurations.navigationDelay, _navigateNext);
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    final storage = ref.read(secureStorageProvider);
    final token = await storage.getAuthToken();
    final role = await storage.getUserRole();
    final childSession = await storage.getChildSession();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      context.go(Routes.language);
      return;
    }
    if (role == 'parent') {
      context.go(Routes.parentDashboard);
      return;
    }
    if (role == 'child') {
      context.go(childSession != null ? Routes.childHome : Routes.childLogin);
      return;
    }
    context.go(Routes.selectUserType);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _SplashLayout.fromConstraints(constraints);
            return _SplashScene(layout: layout);
          },
        ),
      ),
    );
  }
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.layout});

  final _SplashLayout layout;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: _AssetImage(
            assetPath: _SplashAssets.background,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: layout.starsHeight,
          child: const IgnorePointer(
            child: _AnimatedAsset(
              animation: _FloatAnimationSpec(
                duration: _SplashDurations.backgroundStarsFloat,
                offset: 5,
              ),
              child: _AssetImage(
                assetPath: _SplashAssets.stars,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        ),
        Positioned(
          top: layout.haloTop,
          left: layout.haloLeft,
          width: layout.haloWidth,
          child: const IgnorePointer(
            child: _AnimatedAsset(
              animation: _PulseAnimationSpec(
                duration: _SplashDurations.haloPulse,
                minScale: 0.98,
                maxScale: 1.03,
                minOpacity: 0.86,
                maxOpacity: 1,
              ),
              child: _AssetImage(
                assetPath: _SplashAssets.halo,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          top: layout.boyTop,
          left: layout.boyLeft,
          height: layout.boyHeight,
          child: const IgnorePointer(
            child: _AssetImage(
              assetPath: _SplashAssets.boy,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          top: layout.planetTop,
          right: layout.planetRight,
          width: layout.planetWidth,
          child: const IgnorePointer(
            child: _AnimatedAsset(
              animation: _FloatAnimationSpec(
                duration: _SplashDurations.planetFloat,
                offset: 8,
              ),
              child: _AssetImage(
                assetPath: _SplashAssets.planet,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          top: layout.bookTop,
          left: layout.bookLeft,
          width: layout.bookWidth,
          child: const IgnorePointer(
            child: _AnimatedAsset(
              animation: _FloatAnimationSpec(
                duration: _SplashDurations.bookFloat,
                offset: 6,
              ),
              child: _AssetImage(
                assetPath: _SplashAssets.book,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          top: layout.starTop,
          left: layout.starLeft,
          width: layout.starWidth,
          child: const IgnorePointer(
            child: _AnimatedAsset(
              animation: _FloatAnimationSpec(
                duration: _SplashDurations.starFloat,
                offset: 7,
              ),
              child: _AssetImage(
                assetPath: _SplashAssets.star,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          top: layout.bulbTop,
          right: layout.bulbRight,
          width: layout.bulbWidth,
          child: const IgnorePointer(
            child: _AnimatedAsset(
              animation: _FloatAnimationSpec(
                duration: _SplashDurations.bulbFloat,
                offset: 9,
              ),
              child: _AssetImage(
                assetPath: _SplashAssets.bulb,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          left: layout.textHorizontalPadding,
          right: layout.textHorizontalPadding,
          bottom: layout.textBottom,
          child: _SplashBranding(layout: layout),
        ),
      ],
    );
  }
}

class _SplashBranding extends StatelessWidget {
  const _SplashBranding({required this.layout});

  final _SplashLayout layout;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFD177C9),
              Color(0xFF78A9FF),
              Color(0xFF8FD59A),
              Color(0xFFFFA8B5),
            ],
          ).createShader(bounds),
          child: Text(
            'Kinder World',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: layout.titleFontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
        ),
        SizedBox(height: layout.taglineSpacing),
        Text(
          'Learn • Play • Grow',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF184F86),
            fontSize: layout.taglineFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _AssetImage extends StatelessWidget {
  const _AssetImage({
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final String assetPath;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(assetPath, fit: fit, alignment: alignment);
  }
}

class _AnimatedAsset extends StatefulWidget {
  const _AnimatedAsset({
    required this.animation,
    required this.child,
  });

  final _AssetAnimationSpec animation;
  final Widget child;

  @override
  State<_AnimatedAsset> createState() => _AnimatedAssetState();
}

class _AnimatedAssetState extends State<_AnimatedAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animation.duration,
    )..repeat(reverse: true);
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    return AnimatedBuilder(
      animation: _curvedAnimation,
      child: widget.child,
      builder: (context, child) {
        final translationY = animation.translationY(_curvedAnimation.value);
        final scale = animation.scale(_curvedAnimation.value);
        final opacity = animation.opacity(_curvedAnimation.value);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translationY),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

abstract class _AssetAnimationSpec {
  const _AssetAnimationSpec({required this.duration});

  final Duration duration;

  double translationY(double t) => 0;

  double scale(double t) => 1;

  double opacity(double t) => 1;
}

class _FloatAnimationSpec extends _AssetAnimationSpec {
  const _FloatAnimationSpec({
    required super.duration,
    required this.offset,
  });

  final double offset;

  @override
  double translationY(double t) => lerpDouble(-offset, offset, t)!;
}

class _PulseAnimationSpec extends _AssetAnimationSpec {
  const _PulseAnimationSpec({
    required super.duration,
    required this.minScale,
    required this.maxScale,
    required this.minOpacity,
    required this.maxOpacity,
  });

  final double minScale;
  final double maxScale;
  final double minOpacity;
  final double maxOpacity;

  @override
  double scale(double t) => lerpDouble(minScale, maxScale, t)!;

  @override
  double opacity(double t) => lerpDouble(minOpacity, maxOpacity, t)!;
}

class _SplashLayout {
  const _SplashLayout({
    required this.width,
    required this.height,
    required this.starsHeight,
    required this.haloTop,
    required this.haloLeft,
    required this.haloWidth,
    required this.boyTop,
    required this.boyLeft,
    required this.boyHeight,
    required this.planetTop,
    required this.planetRight,
    required this.planetWidth,
    required this.bookTop,
    required this.bookLeft,
    required this.bookWidth,
    required this.starTop,
    required this.starLeft,
    required this.starWidth,
    required this.bulbTop,
    required this.bulbRight,
    required this.bulbWidth,
    required this.textHorizontalPadding,
    required this.textBottom,
    required this.titleFontSize,
    required this.taglineFontSize,
    required this.taglineSpacing,
  });

  factory _SplashLayout.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final scale = (width / 390).clamp(0.85, 1.18);

    final haloWidth = width * 0.78;
    final boyHeight = height * 0.58;
    final boyWidth = boyHeight * 0.62;
    final starWidth = width * 0.17;

    return _SplashLayout(
      width: width,
      height: height,
      starsHeight: height * 0.46,
      haloTop: height * 0.19,
      haloLeft: (width - haloWidth) / 2,
      haloWidth: haloWidth,
      boyTop: height * 0.17,
      boyLeft: (width - boyWidth) / 2,
      boyHeight: boyHeight,
      planetTop: height * 0.24,
      planetRight: width * 0.08,
      planetWidth: width * 0.38,
      bookTop: height * 0.17,
      bookLeft: width * 0.08,
      bookWidth: width * 0.22,
      starTop: height * 0.10,
      starLeft: (width - starWidth) / 2,
      starWidth: starWidth,
      bulbTop: height * 0.43,
      bulbRight: width * 0.08,
      bulbWidth: width * 0.18,
      textHorizontalPadding: width * 0.08,
      textBottom: height * 0.08,
      titleFontSize: 44 * scale,
      taglineFontSize: 20 * scale,
      taglineSpacing: 10 * scale,
    );
  }

  final double width;
  final double height;
  final double starsHeight;
  final double haloTop;
  final double haloLeft;
  final double haloWidth;
  final double boyTop;
  final double boyLeft;
  final double boyHeight;
  final double planetTop;
  final double planetRight;
  final double planetWidth;
  final double bookTop;
  final double bookLeft;
  final double bookWidth;
  final double starTop;
  final double starLeft;
  final double starWidth;
  final double bulbTop;
  final double bulbRight;
  final double bulbWidth;
  final double textHorizontalPadding;
  final double textBottom;
  final double titleFontSize;
  final double taglineFontSize;
  final double taglineSpacing;
}

class _SplashAssets {
  static const background = 'assets/images/background.png';
  static const stars = 'assets/images/small_stars.png';
  static const halo = 'assets/images/halo.png';
  static const boy = 'assets/images/boy.png';
  static const planet = 'assets/images/planet.png';
  static const book = 'assets/images/book2.png';
  static const star = 'assets/images/star.png';
  static const bulb = 'assets/images/bulb.png';
}

class _SplashDurations {
  static const screenFadeIn = Duration(milliseconds: 900);
  static const navigationDelay = Duration(milliseconds: 2900);
  static const backgroundStarsFloat = Duration(milliseconds: 4200);
  static const haloPulse = Duration(milliseconds: 2400);
  static const starFloat = Duration(milliseconds: 2600);
  static const bookFloat = Duration(milliseconds: 3000);
  static const bulbFloat = Duration(milliseconds: 3400);
  static const planetFloat = Duration(milliseconds: 3600);
}
