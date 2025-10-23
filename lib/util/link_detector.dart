
import 'dart:core';

class LinkInfo {
  final String url;
  final String type; // 'youtube' | 'tiktok' | 'facebook' | 'other'
  final String? youtubeId;
  const LinkInfo(this.url, this.type, {this.youtubeId});
}

final _urlRegex = RegExp(
  r'(https?:\/\/[^\s]+)',
  caseSensitive: false,
);

List<LinkInfo> parseLinks(String text) {
  final found = <LinkInfo>[];
  for (final m in _urlRegex.allMatches(text)) {
    final url = m.group(0)!;
    found.add(_classify(url));
  }
  return found;
}

LinkInfo _classify(String url) {
  final u = url.toLowerCase();
  // YouTube long, shorts, and youtu.be
  final ytId = _youtubeIdFromUrl(url);
  if (ytId != null) return LinkInfo(url, 'youtube', youtubeId: ytId);

  // TikTok (vm.tiktok.com or tiktok.com/@.../video/...)
  if (u.contains('tiktok.com')) return LinkInfo(url, 'tiktok');

  // Facebook Reels (reel/reels/fb.watch)
  if (u.contains('facebook.com/reel') || u.contains('facebook.com/reels') || u.contains('fb.watch')) {
    return LinkInfo(url, 'facebook');
  }

  return LinkInfo(url, 'other');
}

String? _youtubeIdFromUrl(String url) {
  // supports: https://www.youtube.com/watch?v=VIDEO_ID
  //           https://youtu.be/VIDEO_ID
  //           https://www.youtube.com/shorts/VIDEO_ID
  final u = Uri.tryParse(url);
  if (u == null) return null;
  final host = (u.host).toLowerCase();
  if (host.contains('youtu.be')) {
    final segs = u.pathSegments;
    if (segs.isNotEmpty) return segs.first;
  }
  if (host.contains('youtube.com')) {
    if (u.pathSegments.contains('watch')) {
      final id = u.queryParameters['v'];
      if (id != null && id.isNotEmpty) return id;
    }
    if (u.pathSegments.contains('shorts')) {
      final idx = u.pathSegments.indexOf('shorts');
      if (idx >= 0 && u.pathSegments.length > idx + 1) return u.pathSegments[idx + 1];
    }
  }
  return null;
}
