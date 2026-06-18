import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../providers/messages_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/online_dot.dart';
import '../widgets/message/message_bubble.dart';
import '../widgets/message/message_input_bar.dart';
import '../widgets/message/typing_indicator.dart';

class ChatThreadScreen extends StatefulWidget {
  final ChatThread thread;

  const ChatThreadScreen({super.key, required this.thread});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  late final MessagesProvider _messagesProvider;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messagesProvider = MessagesProvider(
      threadId: widget.thread.id,
      schoolId: widget.thread.schoolId,
    );
    _messagesProvider.loadMessages();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Load more when scrolled to top (older messages)
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 100) {
      if (_messagesProvider.hasMore && !_messagesProvider.isLoading) {
        _messagesProvider.loadMessages();
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _messagesProvider.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _messagesProvider,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Broadcast banner
            if (widget.thread.isBroadcast) _buildBroadcastBanner(),

            // Messages list
            Expanded(child: _buildMessagesList()),

            // Typing indicator
            Consumer<MessagesProvider>(
              builder: (_, p, __) => p.isTyping
                  ? TypingIndicator(userName: p.typingUser ?? '')
                  : const SizedBox.shrink(),
            ),

            // Input bar
            MessageInputBar(
              onSendText: (text) async {
                await _messagesProvider.sendTextMessage(text);
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom());
              },
              onTyping: (isTyping) =>
                  _messagesProvider.updateTypingStatus(isTyping),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  widget.thread.displayName.isNotEmpty
                      ? widget.thread.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.w700),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: OnlineDot(isOnline: widget.thread.isOnline, size: 10),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.thread.displayName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.thread.isOnline
                      ? 'Online'
                      : widget.thread.lastSeen != null
                          ? 'Last seen recently'
                          : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.thread.isOnline
                        ? AppColors.accent
                        : AppColors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: _showThreadOptions,
        ),
      ],
    );
  }

  Widget _buildBroadcastBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.accentLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Class Announcement — replies are private to you',
              style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Consumer<MessagesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.messages.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (provider.messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'This is the beginning of your conversation\nwith ${widget.thread.displayName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(animated: false));

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: provider.messages.length +
              (provider.isLoading ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == 0 && provider.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              );
            }
            final msgIndex = provider.isLoading ? i - 1 : i;
            final message = provider.messages[msgIndex];

            // Mark as seen
            if (!message.isMe &&
                message.status != MessageStatus.seen) {
              provider.markSeen(message.id);
            }

            return MessageBubble(
              message: message,
              onEdit: message.canEdit
                  ? (newContent) =>
                      provider.editMessage(message.id, newContent)
                  : null,
            ).animate(delay: 50.ms).fadeIn(duration: 200.ms);
          },
        );
      },
    );
  }

  void _showThreadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search_rounded,
                  color: AppColors.primary),
              title: const Text('Search in conversation'),
              onTap: () {
                Navigator.pop(context);
                // TODO: open in-thread search
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_rounded,
                  color: AppColors.textSecondary),
              title: const Text('Mute notifications'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
