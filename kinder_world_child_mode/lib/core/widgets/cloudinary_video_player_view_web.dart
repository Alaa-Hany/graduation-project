import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/utils/video_url_utils.dart';
import 'package:web/web.dart' as web;

class CloudinaryVideoPlayerView extends StatefulWidget {
  const CloudinaryVideoPlayerView({
    super.key,
    required this.videoUrl,
    this.active = true,
  });

  final String videoUrl;

  /// When set to `false` the player is silenced (and a YouTube iframe blanked)
  /// so its audio stops even though the widget stays mounted — e.g. once the
  /// child taps "I'm done" and moves on to the quiz on the same page.
  final bool active;

  @override
  State<CloudinaryVideoPlayerView> createState() =>
      _CloudinaryVideoPlayerViewState();
}

class _CloudinaryVideoPlayerViewState extends State<CloudinaryVideoPlayerView> {
  static int _nextViewId = 0;
  late final String _viewType;
  late final web.HTMLElement _playerElement;

  /// The YouTube embed URL (null for a direct Cloudinary video), kept so we can
  /// restore the iframe after blanking it to silence background audio.
  String? _youtubeEmbedUrl;

  /// Collapsed/expanded height of the embedded player on the page.
  static const double _collapsedHeight = 320;
  static const double _expandedHeight = 540;
  bool _expanded = false;

  /// The host route's secondary animation, watched so we can pause the video
  /// when another page (e.g. the quiz) is pushed on top of this one.
  Animation<double>? _secondaryAnimation;

  @override
  void initState() {
    super.initState();
    _viewType = 'cloudinary-video-${widget.videoUrl.hashCode}-${_nextViewId++}';
    final youtubeEmbed = youtubeEmbedUrl(widget.videoUrl);
    _youtubeEmbedUrl = youtubeEmbed;
    if (youtubeEmbed != null) {
      _playerElement = web.HTMLIFrameElement()
        ..src = youtubeEmbed
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
        ..allowFullscreen = true
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    } else {
      _playerElement = web.HTMLVideoElement()
        ..src = widget.videoUrl
        ..controls = true
        ..preload = 'metadata'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..load();
    }
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      return _playerElement;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch the host route's secondary animation: it drives forward (0 -> 1)
    // when another page is pushed on top of this one. That page (e.g. the quiz)
    // covers — but does not dispose — this widget, so we pause the video here to
    // stop its audio leaking through in the background.
    final secondary = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(secondary, _secondaryAnimation)) {
      _secondaryAnimation?.removeStatusListener(_onSecondaryAnimationStatus);
      _secondaryAnimation = secondary;
      _secondaryAnimation?.addStatusListener(_onSecondaryAnimationStatus);
    }
  }

  @override
  void didUpdateWidget(CloudinaryVideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _restorePlayback();
      } else {
        _silencePlayback();
      }
    }
  }

  void _onSecondaryAnimationStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
      case AnimationStatus.completed:
        // Another page (e.g. the quiz) is covering this one — silence the video.
        _silencePlayback();
      case AnimationStatus.reverse:
      case AnimationStatus.dismissed:
        // The page on top was popped — bring the player back.
        _restorePlayback();
    }
  }

  /// Stops the embedded player's audio while this page is covered by another.
  void _silencePlayback() {
    final element = _playerElement;
    if (element is web.HTMLVideoElement) {
      element.pause();
    } else if (element is web.HTMLIFrameElement) {
      // Ask the YouTube player to pause first (keeps the playback position when
      // it lands), then blank the iframe so the audio is guaranteed to stop even
      // if the postMessage command isn't honoured.
      element.contentWindow?.postMessage(
        '{"event":"command","func":"pauseVideo","args":""}'.toJS,
        '*'.toJS,
      );
      if (element.src != 'about:blank') {
        element.src = 'about:blank';
      }
    }
  }

  /// Restores the iframe player after [_silencePlayback] blanked it.
  void _restorePlayback() {
    final element = _playerElement;
    final embed = _youtubeEmbedUrl;
    if (element is web.HTMLIFrameElement &&
        embed != null &&
        element.src != embed) {
      element.src = embed;
    }
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeStatusListener(_onSecondaryAnimationStatus);
    final element = _playerElement;
    if (element is web.HTMLVideoElement) {
      element.pause();
    } else if (element is web.HTMLIFrameElement) {
      // A YouTube embed keeps playing (and its audio keeps coming through) even
      // after the Flutter view is gone. Blanking the iframe src tears down the
      // embedded player so the sound doesn't linger in the background once the
      // child leaves the page.
      element.src = 'about:blank';
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                height: _expanded ? _expandedHeight : _collapsedHeight,
                width: double.infinity,
                child: HtmlElementView(viewType: _viewType),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: _expanded
                        ? MaterialLocalizations.of(context).closeButtonTooltip
                        : l10n.playWatchVideoAction,
                    icon: Icon(
                      _expanded
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.playWatchVideoAction,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
