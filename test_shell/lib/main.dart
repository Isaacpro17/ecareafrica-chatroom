import 'package:flutter/material.dart';
import 'package:netrack_chatroom/chatroom.dart';
import 'package:netrack_chatroom/src/services/api_service.dart';
import 'mock_users.dart';
import 'package:netrack_chatroom/src/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force clear ALL secure storage on every dev startup
  const storage = FlutterSecureStorage();
  await storage.deleteAll();

  // Initialize the chatroom package pointing to local dev backend
  await ChatroomService.initialize(
    apiBaseUrl: 'http://192.168.1.70:3000',
    firebaseOptions: null,
  );

  runApp(const TestShellApp());
}

class TestShellApp extends StatelessWidget {
  const TestShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netrack Chat — Dev Shell',
      debugShowCheckedModeBanner: true,
      theme: AppTheme.light,
      home: const RolePickerScreen(),
    );
  }
}

class RolePickerScreen extends StatelessWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  'packages/netrack_chatroom/assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.school_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Dev Shell — Pick a User'),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Branded header ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A237E),
                  Color(0xFF1565C0),
                  Color(0xFF2196F3)
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A237E).withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'packages/netrack_chatroom/assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school_rounded,
                        size: 48,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Education Care Africa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chatroom — Development Shell',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const _SectionHeader('Parents'),
          ...MockUsers.parents.map((u) => _UserTile(user: u)),
          const _SectionHeader('Teachers'),
          ...MockUsers.teachers.map((u) => _UserTile(user: u)),
          const _SectionHeader('Students'),
          ...MockUsers.students.map((u) => _UserTile(user: u)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1565C0),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final MockUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1565C0),
          child: Text(
            user.name[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user.name),
        subtitle: Text('${user.role} • ${user.id}'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => _launch(context, user),
      ),
    );
  }

  Future<void> _launch(BuildContext context, MockUser user) async {
    try {
      final res = await ApiService.getTestToken({
        'user_id': user.id,
        'school_id': user.schoolId,
        'role': user.role,
      });
      final token = res.data['token'] as String;

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatroomWidget(
            userToken: user.role == 'student' ? null : token,
            schoolId: user.schoolId,
            userRole: user.role,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get test token: $e')),
      );
    }
  }
}
