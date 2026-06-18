import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/threads_provider.dart';
import '../../models/chat_thread.dart';
import '../../theme/app_theme.dart';
import '../chat_thread_screen.dart';

class RollNumberSearchScreen extends StatefulWidget {
  const RollNumberSearchScreen({super.key});

  @override
  State<RollNumberSearchScreen> createState() =>
      _RollNumberSearchScreenState();
}

class _RollNumberSearchScreenState extends State<RollNumberSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final res = await ApiService.searchByRollNumber(query.trim());
      setState(() {
        _results = List<Map<String, dynamic>>.from(
            res.data['data'] as List? ?? []);
      });
    } catch (e) {
      setState(() => _error = 'Search unavailable. Tap to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Search by Roll Number'),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppColors.primaryDark,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.white),
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Enter student roll number…',
                hintStyle:
                    TextStyle(color: AppColors.white.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search,
                    color: AppColors.white.withOpacity(0.7)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: AppColors.accent),
                  onPressed: () => _search(_controller.text),
                ),
                filled: true,
                fillColor: AppColors.white.withOpacity(0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Results
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _search(_controller.text),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_rounded,
                  size: 72, color: AppColors.textHint),
              SizedBox(height: 16),
              Text(
                'Enter a student roll number\nto find their contacts',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 64, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(
                'No student found for "${_controller.text}".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final student = _results[i];
        final contacts =
            student['contacts'] as List? ?? [];
        return _StudentResultCard(
          student: student,
          contacts: contacts,
          onContactTap: (contact) =>
              _openOrCreateThread(student, contact),
        )
            .animate(delay: (i * 80).ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.05, end: 0);
      },
    );
  }

  Future<void> _openOrCreateThread(
      Map<String, dynamic> student, Map<String, dynamic> contact) async {
    try {
      final res = await ApiService.createThread({
        'teacher_id': contact['teacher_id'] ?? '',
        'student_id': student['student_id'],
        'thread_type': 'direct',
        'thread_initiator': contact['type'] == 'student' ? 'student' : 'parent',
        'parent_id': contact['type'] == 'parent' ? contact['id'] : null,
      });
      final thread =
          ChatThread.fromJson(res.data['data'] as Map<String, dynamic>);
      if (!mounted) return;
      context.read<ThreadsProvider>().addOrUpdateThread(thread);
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatThreadScreen(thread: thread)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open chat. Please try again.')),
      );
    }
  }
}

class _StudentResultCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final List contacts;
  final void Function(Map<String, dynamic>) onContactTap;

  const _StudentResultCard({
    required this.student,
    required this.contacts,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['full_name'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Roll: ${student['admission_number']} • '
                        'Class ${student['class_name']} ${student['section']}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (contacts.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('Contacts',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint)),
              const SizedBox(height: 8),
              ...contacts.map((c) {
                final contact = c as Map<String, dynamic>;
                final isStudent = contact['type'] == 'student';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isStudent
                        ? AppColors.primarySurface
                        : AppColors.accentLight,
                    child: Icon(
                      isStudent
                          ? Icons.person_rounded
                          : Icons.family_restroom_rounded,
                      color: isStudent
                          ? AppColors.primary
                          : AppColors.accent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    contact['name'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    isStudent
                        ? 'Student'
                        : contact['relationship'] as String? ?? 'Parent',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => onContactTap(contact),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Chat', style: TextStyle(fontSize: 12)),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
