
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/providers/app_launch_provider.dart';
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

    final appLaunch = ref.read(appLaunchProvider);
    if (!appLaunch.hasSavedLocale || !appLaunch.hasCompletedOnboarding) {
      final secureStorage = ref.read(secureStorageProvider);
      final hasExistingSession = secureStorage.hasCachedAuthToken
          ? (secureStorage.cachedAuthToken?.isNotEmpty ?? false)
          : ((await secureStorage.getAuthToken())?.isNotEmpty ?? false);
      if (hasExistingSession) {
        if (!mounted) return;
        context.go(Routes.selectUserType);
        return;
      }
    }
    if (!mounted) return;

    if (!appLaunch.hasSavedLocale) {
      context.go(Routes.language);
      return;
    }
    if (!appLaunch.hasCompletedOnboarding) {
      context.go(Routes.onboarding);
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
        const Positioned.fill(child: _SplashBackground()),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SparklesPainter(),
            ),
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
          top: layout.book2Top,
          left: layout.book2Left,
          width: layout.book2Width,
          child: const IgnorePointer(
            child: _AnimatedAsset(
              animation: _FloatAnimationSpec(
                duration: _SplashDurations.book2Float,
                offset: 7,
              ),
              child: _AssetImage(
                assetPath: _SplashAssets.book2,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          top: layout.starTop,
          left: layout.starLeft,
          width: layout.starWidth,
          child: IgnorePointer(
            child: _AnimatedAsset(
              animation: const _FloatAnimationSpec(
                duration: _SplashDurations.starFloat,
                offset: 7,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const _AssetImage(
                      assetPath: _SplashAssets.star,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const _AssetImage(
                    assetPath: _SplashAssets.star,
                    fit: BoxFit.contain,
                  ),
                ],
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
          bottom: 0,
          left: 0,
          right: 0,
          height: layout.fogHeight,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xB3FFFFFF),
                    Color(0x55FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
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
        Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Text(
                'Kinder World',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: layout.titleFontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ),
            Text(
              'Kinder World',
              textAlign: TextAlign.center,
              style: TextStyle(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = layout.titleStrokeWidth
                  ..color = Colors.white,
                fontSize: layout.titleFontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFE98BC8),
                  Color(0xFF8F89E7),
                  Color(0xFF77B8FF),
                  Color(0xFF8BE18A),
                  Color(0xFFF1DA75),
                  Color(0xFFF3A281),
                ],
              ).createShader(bounds),
              child: Text(
                'Kinder World',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: layout.titleFontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: layout.taglineSpacing),
        Text(
          'Learn • Play • Grow',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF1A3A6B),
            fontSize: layout.taglineFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
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

class _SplashLayout {
  const _SplashLayout({
    required this.starsHeight,
    required this.boyTop,
    required this.boyLeft,
    required this.boyHeight,
    required this.planetTop,
    required this.planetRight,
    required this.planetWidth,
    required this.bookTop,
    required this.bookLeft,
    required this.bookWidth,
    required this.book2Top,
    required this.book2Left,
    required this.book2Width,
    required this.starTop,
    required this.starLeft,
    required this.starWidth,
    required this.bulbTop,
    required this.bulbRight,
    required this.bulbWidth,
    required this.fogHeight,
    required this.textHorizontalPadding,
    required this.textBottom,
    required this.titleFontSize,
    required this.titleStrokeWidth,
    required this.taglineFontSize,
    required this.taglineSpacing,
  });

  factory _SplashLayout.fromConstraints(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final scale = (width / 390).clamp(0.85, 1.18);

    final boyHeight = height * 0.7;
    final boyWidth = boyHeight * 0.45; // Estimated aspect ratio for character image
    final boyLeft = (width - boyWidth) / 2 - boyWidth * 0.21; // Center horizontally

    final textBottom = height * 0.12;
    final taglineFontSize = 18 * scale;
    final titleFontSize = 42 * scale;
    final taglineSpacing = 12 * scale;

    final brandingHeight = titleFontSize + taglineSpacing + taglineFontSize + 15;
    final boyTop = height - textBottom - brandingHeight - boyHeight + 40 ;

    final starWidth = width * 0.11;

    return _SplashLayout(
      starsHeight: height * 0.78,
      boyTop: boyTop,
      boyLeft: boyLeft,
      boyHeight: boyHeight,

      planetTop: height * 0.13,
      planetRight: width * 0.04,
      planetWidth: width * 0.17,

      bookTop: height * 0.15,
      bookLeft: width * 0.07,
      bookWidth: width * 0.16,

      book2Top: height * 0.65,
      book2Left: width * 0.33,
      book2Width: width * 0.15,

      starTop: height * 0.13,
      starLeft: width * 0.6,
      starWidth: starWidth,

      bulbTop: height * 0.63,
      bulbRight: width * 0.06,
      bulbWidth: width * 0.13,

      fogHeight: height * 0.34,
      textHorizontalPadding: width * 0.06,
      textBottom: textBottom,

      titleFontSize: titleFontSize,
      titleStrokeWidth: 8 * scale,
      taglineFontSize: taglineFontSize,
      taglineSpacing: taglineSpacing,
    );
  }

  final double starsHeight;
  final double boyTop;
  final double boyLeft;
  final double boyHeight;
  final double planetTop;
  final double planetRight;
  final double planetWidth;
  final double bookTop;
  final double bookLeft;
  final double bookWidth;
  final double book2Top;
  final double book2Left;
  final double book2Width;
  final double starTop;
  final double starLeft;
  final double starWidth;
  final double bulbTop;
  final double bulbRight;
  final double bulbWidth;
  final double fogHeight;
  final double textHorizontalPadding;
  final double textBottom;
  final double titleFontSize;
  final double titleStrokeWidth;
  final double taglineFontSize;
  final double taglineSpacing;
}

class _SplashAssets {
  static const stars = 'assets/images/small_stars.png';
  static const boy = 'assets/images/boy.png';
  static const planet = 'assets/images/planet.png';
  static const book = 'assets/images/book2.png';
  static const book2 = 'assets/images/book1.png';
  static const star = 'assets/images/star.png';
  static const bulb = 'assets/images/bulb.png';
}

class _SplashDurations {
  static const screenFadeIn = Duration(milliseconds: 260);
  static const navigationDelay = Duration(seconds: 3);
  static const backgroundStarsFloat = Duration(milliseconds: 4200);
  static const starFloat = Duration(milliseconds: 2600);
  static const bookFloat = Duration(milliseconds: 3000);
  static const book2Float = Duration(milliseconds: 3200);
  static const bulbFloat = Duration(milliseconds: 3400);
  static const planetFloat = Duration(milliseconds: 3600);
}

class _SparklesPainter extends CustomPainter {
  const _SparklesPainter();

  static const List<List<double>> _sparkles = [
    [0.14, 0.10, 6.0, 0.90],
    [0.83, 0.13, 5.5, 0.85],
    [0.07, 0.28, 4.5, 0.70],
    [0.91, 0.26, 5.0, 0.80],
    [0.22, 0.48, 4.0, 0.65],
    [0.78, 0.44, 4.5, 0.75],
    [0.10, 0.60, 3.5, 0.60],
    [0.89, 0.58, 4.0, 0.68],
    [0.36, 0.16, 3.0, 0.60],
    [0.66, 0.20, 3.5, 0.65],
    [0.50, 0.06, 4.5, 0.80],
    [0.18, 0.74, 3.0, 0.50],
    [0.82, 0.72, 3.5, 0.55],
    [0.44, 0.38, 2.5, 0.45],
    [0.62, 0.64, 3.0, 0.52],
    [0.30, 0.85, 2.5, 0.40],
    [0.70, 0.82, 3.0, 0.45],
    [0.55, 0.52, 2.0, 0.38],
    [0.05, 0.45, 3.0, 0.55],
    [0.95, 0.40, 3.5, 0.60],
  ];

  void _drawSparkle(
      Canvas canvas,
      double cx,
      double cy,
      double size,
      double opacity,
      ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    const points = 8;
    for (int i = 0; i < points; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final radius = i.isEven ? size : size * 0.28;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.18,
      Paint()..color = Colors.white.withValues(alpha: opacity * 0.9),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final sparkle in _sparkles) {
      _drawSparkle(
        canvas,
        size.width * sparkle[0],
        size.height * sparkle[1],
        sparkle[2],
        sparkle[3],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
