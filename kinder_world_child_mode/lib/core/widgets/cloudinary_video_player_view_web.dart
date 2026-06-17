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

  @override
  void initState() {
    super.initState();
    _viewType = 'cloudinary-video-${widget.videoUrl.hashCode}-${_nextViewId++}';
    final youtubeEmbed = youtubeEmbedUrl(widget.videoUrl);
    if (youtubeEmbed != null) {
      _playerElement = web.HTMLIFrameElement()
        ..src = youtubeEmbed
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
    if (_playerElement is web.HTMLVideoElement) {
      (_playerElement as web.HTMLVideoElement).pause();
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
          child: SizedBox(
            height: 320,
            width: double.infinity,
            child: HtmlElementView(viewType: _viewType),
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
