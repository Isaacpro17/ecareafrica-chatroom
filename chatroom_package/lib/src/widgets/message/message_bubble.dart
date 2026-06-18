import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import '../../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String newContent)? onEdit;

  const MessageBubble({super.key, required this.message, this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _SystemMessage(message: message);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primarySurface,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onEdit != null ? () => _showEditDialog(context) : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: message.isBroadcast
                      ? AppColors.bubbleBroadcast
                      : message.isMe
                          ? AppColors.bubbleSent
                          : AppColors.bubbleReceived,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(message.isMe ? 18 : 4),
                    bottomRight: Radius.circular(message.isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Broadcast label
                    if (message.isBroadcast)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.campaign_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Class Announcement',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Content
                    _buildContent(),

                    const SizedBox(height: 4),

                    // Footer: time + status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isEdited)
                          Text(
                            '(Edited) ',
                            style: TextStyle(
                              fontSize: 10,
                              color: message.isMe
                                  ? AppColors.white.withOpacity(0.6)
                                  : AppColors.textHint,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        Text(
                          DateFormat('HH:mm').format(message.sentAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: message.isMe
                                ? AppColors.white.withOpacity(0.7)
                                : AppColors.textHint,
                          ),
                        ),
                        if (message.isMe) ...[
                          const SizedBox(width: 4),
                          _StatusIcon(status: message.status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (message.messageType) {
      case MessageType.text:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            color: message.isMe ? AppColors.white : AppColors.textPrimary,
            height: 1.4,
          ),
        );
      case MessageType.image:
        return _ImageContent(message: message);
      case MessageType.document:
        return _DocumentContent(message: message);
      case MessageType.voice:
        return _VoiceContent(message: message);
      default:
        return const SizedBox.shrink();
    }
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Edit your message…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && text != message.content) {
                onEdit!(text);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
      case MessageStatus.retrying:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: Colors.white54),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageStatus.seen:
        return const Icon(Icons.done_all, size: 14, color: AppColors.accent);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.redAccent);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SystemMessage extends StatelessWidget {
  final ChatMessage message;
  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.content ?? '',
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final ChatMessage message;
  const _ImageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.image_rounded,
                size: 48, color: AppColors.textHint),
          ),
        ),
        if (message.originalFilename != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message.originalFilename!,
              style: TextStyle(
                fontSize: 11,
                color: message.isMe
                    ? AppColors.white.withOpacity(0.7)
                    : AppColors.textHint,
              ),
            ),
          ),
      ],
    );
  }
}

class _DocumentContent extends StatelessWidget {
  final ChatMessage message;
  const _DocumentContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final sizeKb = message.mediaSizeBytes != null
        ? '${(message.mediaSizeBytes! / 1024).toStringAsFixed(1)} KB'
        : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: message.isMe
                ? AppColors.white.withOpacity(0.2)
                : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.insert_drive_file_rounded,
              color: message.isMe ? AppColors.white : AppColors.primary,
              size: 24),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.originalFilename ?? 'Document',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: message.isMe ? AppColors.white : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (sizeKb.isNotEmpty)
                Text(
                  sizeKb,
                  style: TextStyle(
                    fontSize: 11,
                    color: message.isMe
                        ? AppColors.white.withOpacity(0.7)
                        : AppColors.textHint,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceContent extends StatelessWidget {
  final ChatMessage message;
  const _VoiceContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.play_circle_filled_rounded,
          color: message.isMe ? AppColors.white : AppColors.primary,
          size: 36,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 24,
                width: 120,
                decoration: BoxDecoration(
                  color: message.isMe
                      ? AppColors.white.withOpacity(0.2)
                      : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('▬▬▬▬▬▬▬▬',
                      style: TextStyle(
                          fontSize: 8, color: AppColors.textHint)),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Voice message',
                style: TextStyle(
                  fontSize: 11,
                  color: message.isMe
                      ? AppColors.white.withOpacity(0.7)
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
