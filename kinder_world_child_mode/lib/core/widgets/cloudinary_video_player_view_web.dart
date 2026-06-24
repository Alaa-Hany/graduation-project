import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/utils/video_url_utils.dart';
import 'package:web/web.dart' as web;

class CloudinaryVideoPlayerView extends StatefulWidget {
  const CloudinaryVideoPlayerView({
    super.key,
    required this.videoUrl,
  });

  final String videoUrl;

  @override
  State<CloudinaryVideoPlayerView> createState() =>
      _CloudinaryVideoPlayerViewState();
}

class _CloudinaryVideoPlayerViewState extends State<CloudinaryVideoPlayerView> {
  static int _nextViewId = 0;
  late final String _viewType;
  late final web.HTMLElement _playerElement;

  /// Collapsed/expanded height of the embedded player on the page.
  static const double _collapsedHeight = 320;
  static const double _expandedHeight = 540;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'cloudinary-video-${widget.videoUrl.hashCode}-${_nextViewId++}';
    final youtubeEmbed = youtubeEmbedUrl(widget.videoUrl);
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
  void dispose() {
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
