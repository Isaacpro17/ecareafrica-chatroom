import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_context.dart';
import '../../models/chat_thread.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/online_dot.dart';
import '../chat_thread_screen.dart';

class TeacherListScreen extends StatefulWidget {
  final ChildInfo child;

  const TeacherListScreen({super.key, required this.child});

  @override
  State<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends State<TeacherListScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final teachers = widget.child.teachers;

    // Sort: online first, then alphabetically by subject
    final sorted = [...teachers]
      ..sort((a, b) {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return a.subject.compareTo(b.subject);
      });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a Teacher'),
            Text(
              widget.child.fullName,
              style: TextStyle(
                  fontSize: 12, color: AppColors.white.withOpacity(0.75)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header banner
          Container(
            width: double.infinity,
            color: AppColors.primaryDark,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              'Which teacher do you want to talk to?',
              style: TextStyle(
                color: AppColors.white.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error)),
            ),

          Expanded(
            child: teachers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_search_rounded,
                              size: 64, color: AppColors.textHint),
                          const SizedBox(height: 16),
                          Text(
                            'No teachers found for ${widget.child.fullName}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sorted.length,
                    itemBuilder: (context, i) => _TeacherCard(
                      teacher: sorted[i],
                      child: widget.child,
                      onTap: () => _openOrCreateThread(sorted[i]),
                    )
                        .animate(delay: (i * 70).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05, end: 0),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOrCreateThread(TeacherContact teacher) async {
    if (_loading) return; // prevent duplicate taps while request is in flight
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.createThread({
        'teacher_id': teacher.teacherId,
        'student_id': widget.child.studentId,
        'thread_type': 'direct',
        'thread_initiator': 'parent',
      });

      final raw = res.data;
      debugPrint('[TeacherList] createThread response: $raw');

      final data = (raw is Map) ? raw['data'] : null;
      if (data == null) throw Exception('Server returned no thread data');

      final thread = ChatThread.fromJson(Map<String, dynamic>.from(data as Map));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatThreadScreen(thread: thread)),
      );
    } catch (e, st) {
      debugPrint('[TeacherList] _openOrCreateThread error: $e\n$st');
      if (mounted) setState(() => _error = 'Could not open chat. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _TeacherCard extends StatelessWidget {
  final TeacherContact teacher;
  final ChildInfo child;
  final VoidCallback onTap;

  const _TeacherCard({
    required this.teacher,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with online dot
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: teacher.isOnline
                            ? [AppColors.primary, AppColors.primaryLight]
                            : [AppColors.textHint, AppColors.divider],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        teacher.fullName.isNotEmpty
                            ? teacher.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: OnlineDot(isOnline: teacher.isOnline),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${teacher.fullName} — ${teacher.subject} Teacher',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher.isOnline
                          ? 'Online now'
                          : teacher.lastSeen != null
                              ? 'Last seen recently'
                              : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: teacher.isOnline
                            ? AppColors.online
                            : AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        teacher.subject,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
