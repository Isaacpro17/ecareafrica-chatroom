import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/chat_thread.dart';
import '../../theme/app_theme.dart';
import 'online_dot.dart';

class ThreadListTile extends StatelessWidget {
  final ChatThread thread;
  final VoidCallback onTap;

  const ThreadListTile({super.key, required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: hasUnread
            ? const Border(
                left: BorderSide(color: AppColors.primary, width: 3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: thread.isBroadcast
                            ? [AppColors.accent, AppColors.warning]
                            : [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: thread.isBroadcast
                          ? const Icon(Icons.campaign_rounded,
                              color: AppColors.white, size: 26)
                          : Text(
                              thread.displayName.isNotEmpty
                                  ? thread.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  if (!thread.isBroadcast)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: OnlineDot(isOnline: thread.isOnline, size: 10),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread.lastMessageAt != null)
                          Text(
                            timeago.format(thread.lastMessageAt!,
                                allowFromNow: true),
                            style: TextStyle(
                              fontSize: 11,
                              color: hasUnread
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessagePreview ??
                                'Start a conversation',
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (thread.subjectLabel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          thread.subjectLabel!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
