import 'package:flutter/material.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/utils/video_url_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  bool _playerReady = false;
  bool _initializeError = false;
  late final bool _isYouTube;

  @override
  void initState() {
    super.initState();
    _isYouTube = isYouTubeUrl(widget.videoUrl);
    if (_isYouTube) {
      _playerReady = true;
      return;
    }

    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = controller;
    controller.initialize().then((_) {
      controller.setLooping(false);
      if (mounted) {
        setState(() => _playerReady = true);
      }
    }).catchError((_) {
      if (mounted) {
        setState(() => _initializeError = true);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) {
      return;
    }
    final mode =
        _isYouTube ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication;
    await launchUrl(uri, mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isYouTube) {
      final thumbnailUrl = youtubeThumbnailUrl(widget.videoUrl);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl != null)
                    Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.black12),
                    )
                  else
                    Container(color: Colors.black12),
                  Center(
                    child: IconButton.filled(
                      onPressed: _openExternal,
                      icon: const Icon(Icons.play_arrow_rounded),
                      iconSize: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.playWatchVideoAction),
          ),
        ],
      );
    }

    if (_initializeError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.playVideoLaunchFailed),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.playWatchVideoAction),
          ),
        ],
      );
    }

    if (!_playerReady) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio == 0
              ? 16 / 9
              : _controller!.value.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColoredBox(
              color: Colors.black,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        VideoProgressIndicator(
          _controller!,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
            bufferedColor: Theme.of(context).colorScheme.primary.withAlpha(64),
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              icon: Icon(
                _controller!.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.playWatchVideoAction),
            ),
          ],
        ),
      ],
    );
  }
}
