String? extractYouTubeVideoId(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }

  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return segment.trim().isEmpty ? null : segment.trim();
  }

  if (host.contains('youtube.com')) {
    final fromQuery = uri.queryParameters['v']?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) {
      return fromQuery;
    }

    if (uri.pathSegments.length >= 2 &&
        (uri.pathSegments.first == 'embed' ||
            uri.pathSegments.first == 'shorts')) {
      final segment = uri.pathSegments[1].trim();
      return segment.isEmpty ? null : segment;
    }
  }

  return null;
}

bool isYouTubeUrl(String? rawUrl) => extractYouTubeVideoId(rawUrl) != null;

String? youtubeEmbedUrl(String? rawUrl) {
  final id = extractYouTubeVideoId(rawUrl);
  if (id == null) {
    return null;
  }
  // `enablejsapi=1` lets us drive the player over postMessage (e.g. to pause it
  // when the child navigates to a page on top of the video) so its audio does
  // not keep playing in the background.
  return 'https://www.youtube-nocookie.com/embed/$id'
      '?rel=0&modestbranding=1&iv_load_policy=3&playsinline=1&enablejsapi=1';
}

String? youtubeThumbnailUrl(String? rawUrl) {
  final id = extractYouTubeVideoId(rawUrl);
  if (id == null) {
    return null;
  }
  return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}
