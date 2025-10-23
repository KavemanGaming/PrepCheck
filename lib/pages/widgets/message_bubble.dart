import 'package:flutter/material.dart';
import '../../services/time_helper.dart';

class MessageBubble extends StatelessWidget {
  final bool isMe;
  final String senderName;
  final String text;
  final List<Map<String, dynamic>> attachments;
  final DateTime? createdAt;

  /// Optional pre-built widget for attachments (images/videos/files)
  final Widget? attachmentsWidget;

  /// Optional hooks (not required by all callers)
  final void Function(String url)? onOpenImage;
  final void Function(String url)? onOpenVideo;

  /// Optional long-press delete callback
  final VoidCallback? onLongPressDelete;

  const MessageBubble({
    super.key,
    required this.isMe,
    required this.senderName,
    required this.text,
    required this.attachments,
    required this.createdAt,
    this.attachmentsWidget,
    this.onOpenImage,
    this.onOpenVideo,
    this.onLongPressDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isMe
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(senderName, style: Theme.of(context).textTheme.labelMedium),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text),
          ],
          if (attachmentsWidget != null) ...[
            const SizedBox(height: 8),
            attachmentsWidget!,
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              TimeHelper.usTime(createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPressDelete,
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}
