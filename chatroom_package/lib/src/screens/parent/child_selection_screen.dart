import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_context.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'teacher_list_screen.dart';

class ChildSelectionScreen extends StatelessWidget {
  final ChildInfo? preselectedChild;

  const ChildSelectionScreen({super.key, this.preselectedChild});

  @override
  Widget build(BuildContext context) {
    final ctx = AuthService.instance.userContext;

    // If preselected, skip directly to teacher list
    if (preselectedChild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherListScreen(child: preselectedChild!),
          ),
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final children = ctx?.children ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Child'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: children.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.child_care_rounded,
                        size: 64, color: AppColors.textHint),
                    SizedBox(height: 16),
                    Text(
                      'No children found.\nPlease contact your school admin.',
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
              itemCount: children.length,
              itemBuilder: (context, i) {
                final child = children[i];
                return _ChildCard(
                  child: child,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherListScreen(child: child),
                    ),
                  ),
                )
                    .animate(delay: (i * 80).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildInfo child;
  final VoidCallback onTap;

  const _ChildCard({required this.child, required this.onTap});

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
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    child.fullName.isNotEmpty
                        ? child.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Class ${child.classId} — Section ${child.section}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${child.teachers.length} teacher(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryLight,
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
