import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/threads_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/thread_list_tile.dart';
import '../../widgets/common/shimmer_list.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../models/chat_thread.dart';
import '../chat_thread_screen.dart';
import 'roll_number_search_screen.dart';
import 'broadcast_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThreadsProvider>().loadThreads();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = AuthService.instance.userContext;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(ctx?.fullName),
      body: Column(
        children: [
          _buildSearchAndTabs(),
          Expanded(child: _buildTabContent()),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar(String? name) {
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
              if (name != null)
                Text(name,
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
                  margin: const EdgeInsets.only(right: 8),
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
          icon: const Icon(Icons.search_rounded, color: AppColors.white),
          tooltip: 'Search by roll number',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const RollNumberSearchScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
          onPressed: () => context.read<ThreadsProvider>().loadThreads(),
        ),
      ],
    );
  }

  Widget _buildSearchAndTabs() {
    return Container(
      color: AppColors.primaryDark,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'Search conversations…',
                hintStyle:
                    TextStyle(color: AppColors.white.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search,
                    color: AppColors.white.withOpacity(0.7)),
                filled: true,
                fillColor: AppColors.white.withOpacity(0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.white,
            unselectedLabelColor: AppColors.white.withOpacity(0.5),
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'Parent Threads'),
              Tab(text: 'Student Threads'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _ThreadList(
          filter: (t) => t.threadInitiator == ThreadInitiator.parent,
          searchQuery: _searchQuery,
        ),
        _ThreadList(
          filter: (t) => t.threadInitiator == ThreadInitiator.student,
          searchQuery: _searchQuery,
        ),
      ],
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BroadcastScreen()),
      ),
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primaryDark,
      icon: const Icon(Icons.campaign_rounded),
      label: const Text('Broadcast',
          style: TextStyle(fontWeight: FontWeight.w600)),
    ).animate().scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          delay: 400.ms,
          duration: 400.ms,
          curve: Curves.elasticOut,
        );
  }
}

class _ThreadList extends StatelessWidget {
  final bool Function(ChatThread) filter;
  final String searchQuery;

  const _ThreadList({required this.filter, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
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

        var filtered = provider.threads.where(filter).toList();
        if (searchQuery.isNotEmpty) {
          filtered = filtered
              .where((t) =>
                  t.displayName.toLowerCase().contains(searchQuery) ||
                  (t.lastMessagePreview ?? '')
                      .toLowerCase()
                      .contains(searchQuery))
              .toList();
        }

        if (filtered.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No conversations yet',
            subtitle:
                'Use the search icon to find a student by roll number.',
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
              onTap: () {
                provider.markThreadRead(filtered[i].id);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ChatThreadScreen(thread: filtered[i]),
                  ),
                );
              },
            )
                .animate(delay: (i * 50).ms)
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.05, end: 0),
          ),
        );
      },
    );
  }
}
