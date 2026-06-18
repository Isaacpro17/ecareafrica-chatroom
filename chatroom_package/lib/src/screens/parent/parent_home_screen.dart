import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/threads_provider.dart';
import '../../services/auth_service.dart';
import '../../models/chat_thread.dart';
import '../../models/user_context.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/thread_list_tile.dart';
import '../../widgets/common/shimmer_list.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../chat_thread_screen.dart';
import 'child_selection_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThreadsProvider>().loadThreads();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = AuthService.instance.userContext;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(ctx),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar(UserContext? ctx) {
    return AppBar(
      backgroundColor: AppColors.primaryDark,
      elevation: 0,
      title: Row(
        children: [
          // Education Care Africa logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                'packages/netrack_chatroom/assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.school_rounded,
                  size: 22,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chatroom',
                  style: TextStyle(
                      color: AppColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              if (ctx != null)
                Text(ctx.fullName,
                    style: TextStyle(
                        color: AppColors.white.withOpacity(0.75), fontSize: 11)),
            ],
          ),
        ],
      ),
      actions: [
        Consumer<ThreadsProvider>(
          builder: (_, p, __) => p.totalUnread > 0
              ? Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${p.totalUnread}',
                      style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                )
              : const SizedBox.shrink(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
          onPressed: () => context.read<ThreadsProvider>().loadThreads(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: const TextStyle(color: AppColors.white),
        decoration: InputDecoration(
          hintText: 'Search conversations…',
          hintStyle: TextStyle(color: AppColors.white.withOpacity(0.5)),
          prefixIcon:
              Icon(Icons.search, color: AppColors.white.withOpacity(0.7)),
          filled: true,
          fillColor: AppColors.white.withOpacity(0.12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<ThreadsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.threads.isEmpty) {
          return const ShimmerList();
        }
        if (provider.state == LoadState.error) {
          return ErrorState(
            message: provider.errorMessage ?? 'Failed to load chats.',
            onRetry: () => provider.loadThreads(),
          );
        }

        final filtered = _searchQuery.isEmpty
            ? provider.threads
            : provider.threads
                .where((t) =>
                    t.displayName.toLowerCase().contains(_searchQuery) ||
                    (t.lastMessagePreview ?? '')
                        .toLowerCase()
                        .contains(_searchQuery))
                .toList();

        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No conversations yet',
            subtitle: 'Tap the button below to start chatting with a teacher.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => provider.loadThreads(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (context, i) => ThreadListTile(
              thread: filtered[i],
              onTap: () => _openThread(filtered[i]),
            )
                .animate(delay: (i * 50).ms)
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.05, end: 0),
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _startNewChat,
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primaryDark,
      icon: const Icon(Icons.add_comment_rounded),
      label: const Text('New Chat',
          style: TextStyle(fontWeight: FontWeight.w600)),
    ).animate().scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          delay: 400.ms,
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }

  void _openThread(ChatThread thread) {
    context.read<ThreadsProvider>().markThreadRead(thread.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(thread: thread),
      ),
    );
  }

  void _startNewChat() {
    final ctx = AuthService.instance.userContext;
    if (ctx == null) return;

    final route = ctx.children.length == 1
        ? MaterialPageRoute(
            builder: (_) =>
                ChildSelectionScreen(preselectedChild: ctx.children.first),
          )
        : MaterialPageRoute(builder: (_) => const ChildSelectionScreen());

    Navigator.push(context, route).then((_) {
      if (mounted) context.read<ThreadsProvider>().loadThreads();
    });
  }
}
