import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/threads_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/parent/parent_home_screen.dart';
import '../screens/teacher/teacher_home_screen.dart';
import '../screens/student/student_login_screen.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../theme/app_theme.dart';

/// The single entry point widget for the Netrack Chatroom feature.
/// Host app usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => ChatroomWidget(
///     userToken: jwt,
///     schoolId: schoolId,
///     userRole: 'parent', // 'parent' | 'teacher' | 'student'
///   ),
/// ));
/// ```
class ChatroomWidget extends StatefulWidget {
  /// JWT from the host app's auth system.
  final String? userToken;

  /// School UUID.
  final String schoolId;

  /// Role: 'parent' | 'teacher' | 'student'
  final String userRole;

  const ChatroomWidget({
    super.key,
    this.userToken,
    required this.schoolId,
    required this.userRole,
  });

  @override
  State<ChatroomWidget> createState() => _ChatroomWidgetState();
}

class _ChatroomWidgetState extends State<ChatroomWidget>
    with WidgetsBindingObserver {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Set token if provided (parent/teacher flow)
    if (widget.userToken != null) {
      await AuthService.instance.setToken(widget.userToken!);
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctx = AuthService.instance.userContext;
    if (ctx == null) return;
    if (state == AppLifecycleState.resumed) {
      PresenceService.instance.goOnline(ctx.schoolId, ctx.userId);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      PresenceService.instance.goOffline(ctx.schoolId, ctx.userId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PresenceService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThreadsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: _ready ? _resolveHome() : const SplashScreen(),
        routes: {
          '/parent': (_) => const ParentHomeScreen(),
          '/teacher': (_) => const TeacherHomeScreen(),
          '/student': (_) => const StudentLoginScreen(),
        },
      ),
    );
  }

  Widget _resolveHome() {
    if (widget.userRole == 'student') {
      return const StudentLoginScreen();
    }
    return SplashScreen(
      onComplete: () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => ThreadsProvider()),
              ],
              child: widget.userRole == 'teacher'
                  ? const TeacherHomeScreen()
                  : const ParentHomeScreen(),
            ),
          ),
        );
      },
    );
  }
}
