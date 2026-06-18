import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chatroom_service.dart';
import '../services/notification_service.dart';
import '../models/user_context.dart';

/// Animated splash screen shown while the user context is being resolved.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const SplashScreen({super.key, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Initializing…';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Minimum splash display time for brand impression
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (widget.onComplete != null) {
      try {
        // ── BUG FIX: Fetch the full user context and store it in AuthService ──
        // Previously this was calling getChildren() and ignoring the response,
        // which meant AuthService.userContext was always null after login.
        if (mounted) setState(() => _statusText = 'Loading your profile…');
        final res = await ApiService.getMe();
        final contextJson = res.data['data'] as Map<String, dynamic>;
        final userContext = UserContext.fromJson(contextJson);
        AuthService.instance.setUserContext(userContext);

        // Register FCM device token — only when Firebase is available
        if (ChatroomService.isFirebaseAvailable) {
          try {
            final fcmToken = await NotificationService.instance.getDeviceToken();
            if (fcmToken != null) {
              final platform = Platform.isAndroid ? 'android' : 'ios';
              await ApiService.registerDeviceToken(fcmToken, platform);
            }
          } catch (e) {
            debugPrint('[SplashScreen] Device token registration failed: $e');
          }
        }
        // ── End of fix ──────────────────────────────────────────────────────
      } catch (e) {
        // Non-fatal: user context will be null but the UI will handle it gracefully
        debugPrint('[SplashScreen] Could not load user context: $e');
      }
      if (mounted) widget.onComplete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.primaryLight,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Logo ────────────────────────────────────────────────────────
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.45),
                      blurRadius: 40,
                      spreadRadius: 6,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'packages/netrack_chatroom/assets/images/logo.png',
                    fit: BoxFit.contain,
                    // Fallback if asset fails to load
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school_rounded,
                      size: 80,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
                    duration: 700.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 36),

              // App name
              const Text(
                'Education Care Africa',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 8),

              // Feature label
              const Text(
                'CHATROOM',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              )
                  .animate(delay: 450.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),

              const Spacer(flex: 2),

              // Loading indicator
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animate(delay: 600.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 14),

              // Dynamic status text
              Text(
                _statusText,
                style: TextStyle(
                  color: AppColors.white.withOpacity(0.7),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ).animate(delay: 650.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 8),

              Text(
                'Building Africa\'s Digital Education Future',
                style: TextStyle(
                  color: AppColors.white.withOpacity(0.5),
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ).animate(delay: 700.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
