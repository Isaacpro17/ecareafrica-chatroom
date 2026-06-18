import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/threads_provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user_context.dart';
import '../../models/chat_thread.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/shimmer_list.dart';
import '../../widgets/common/online_dot.dart';
import '../chat_thread_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  List<TeacherContact> _teachers = [];
  bool _loadingTeachers = true;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThreadsProvider>().loadThreads();
    });
  }

  Future<void> _loadTeachers() async {
    try {
      final res = await ApiService.getStudentTeachers();
      final list = (res.data['data'] as List? ?? []);
      setState(() {
        _teachers = list
            .map((t) => TeacherContact.fromJson(t as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingTeachers = false);
  }

  @override
  Widget build(BuildContext context) {
    final ctx = AuthService.instance.userContext;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chatroom',
                style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            if (ctx != null)
              Text(ctx.fullName,
                  style: TextStyle(
                      color: AppColors.white.withOpacity(0.75),
                      fontSize: 12)),
          ],
        ),
        actions: [
          Consumer<ThreadsProvider>(
            builder: (_, p, __) => p.totalUnread > 0
                ? Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
        ],
      ),
      body: _loadingTeachers
          ? const ShimmerList()
          : _teachers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded,
                            size: 64, color: AppColors.textHint),
                        SizedBox(height: 16),
                        Text(
                          'No teachers assigned yet.\nContact your school admin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _teachers.length,
                  itemBuilder: (context, i) {
                    final teacher = _teachers[i];
                    return _TeacherCard(
                      teacher: teacher,
                      onTap: () => _openOrCreateThread(teacher),
                    )
                        .animate(delay: (i * 70).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05, end: 0);
                  },
                ),
    );
  }

  bool _openingThread = false;

  Future<void> _openOrCreateThread(TeacherContact teacher) async {
    if (_openingThread) return;
    _openingThread = true;

    final ctx = AuthService.instance.userContext;
    if (ctx == null) {
      _openingThread = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session not ready. Please restart the app.')),
        );
      }
      return;
    }

    try {
      final res = await ApiService.createThread({
        'teacher_id': teacher.teacherId,
        'student_id': ctx.studentId ?? ctx.userId,
        'thread_type': 'direct',
        'thread_initiator': 'student',
      });

      final raw = res.data;
      debugPrint('[StudentHome] createThread response: $raw');

      final data = (raw is Map) ? raw['data'] : null;
      if (data == null) throw Exception('Server returned no thread data');

      final thread = ChatThread.fromJson(Map<String, dynamic>.from(data as Map));
      if (!mounted) return;
      context.read<ThreadsProvider>().addOrUpdateThread(thread);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatThreadScreen(thread: thread)),
      );
    } catch (e, st) {
      debugPrint('[StudentHome] _openOrCreateThread error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open chat. Please try again.')),
        );
      }
    } finally {
      _openingThread = false;
    }
  }
}

class _TeacherCard extends StatelessWidget {
  final TeacherContact teacher;
  final VoidCallback onTap;

  const _TeacherCard({required this.teacher, required this.onTap});

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
                      teacher.isOnline ? 'Online now' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: teacher.isOnline
                            ? AppColors.online
                            : AppColors.textHint,
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
