import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'notification_service.dart';

class ChatroomService {
  ChatroomService._();

  static bool _initialized = false;
  static bool _firebaseAvailable = false;

  static bool get isFirebaseAvailable => _firebaseAvailable;

  static Future<void> initialize({
    required String apiBaseUrl,
    FirebaseOptions? firebaseOptions,
  }) async {
    if (_initialized) return;

    if (firebaseOptions != null) {
      await Firebase.initializeApp(
        name: 'netrack_chatroom',
        options: firebaseOptions,
      );
      _firebaseAvailable = true;
      await NotificationService.instance.initialize();
    } else {
      debugPrint('[ChatroomService] Firebase skipped — running in mock mode');
      _firebaseAvailable = false;
    }

    ApiService.configure(baseUrl: apiBaseUrl);

    _initialized = true;
    debugPrint('[ChatroomService] Initialized — API: $apiBaseUrl');
  }

  static bool get isInitialized => _initialized;
}