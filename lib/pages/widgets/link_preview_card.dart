
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkPreviewCard extends StatelessWidget {
  final String provider; // 'youtube' | 'tiktok' | 'facebook' | 'other'
  final String url;
  final Widget? thumbnail;
  final VoidCallback? onOpenInline;

  const LinkPreviewCard({
    super.key,
    required this.provider,
    required this.url,
    this.thumbnail,
    this.onOpenInline,
  });

  @override
  Widget build(BuildContext context) {
    final isThumb = thumbnail != null;
    return InkWell(
      onTap: onOpenInline ?? () async => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isThumb) SizedBox(height: 158, child: thumbnail!),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(_iconFor(provider), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _titleFor(provider, url),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onOpenInline ?? () async => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    child: Text(onOpenInline != null ? 'Play' : 'Open'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String p) {
    switch (p) {
      case 'youtube':
        return Icons.play_circle_fill;
      case 'tiktok':
        return Icons.music_note;
      case 'facebook':
        return Icons.video_collection;
      default:
        return Icons.link;
    }
  }

  String _titleFor(String p, String url) {
    switch (p) {
      case 'youtube':
        return 'YouTube Video';
      case 'tiktok':
        return 'TikTok Video';
      case 'facebook':
        return 'Facebook Reel';
      default:
        return url;
    }
  }
}
