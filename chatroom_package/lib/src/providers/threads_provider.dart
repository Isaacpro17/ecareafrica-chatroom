import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_thread.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chatroom_service.dart';

enum LoadState { idle, loading, loaded, error }

class ThreadsProvider extends ChangeNotifier {
  List<ChatThread> _threads = [];
  LoadState _state = LoadState.idle;
  String? _errorMessage;
  int _totalUnread = 0;

  final Map<String, StreamSubscription> _firebaseListeners = {};

  List<ChatThread> get threads => _threads;
  LoadState get state => _state;
  String? get errorMessage => _errorMessage;
  int get totalUnread => _totalUnread;
  bool get isLoading => _state == LoadState.loading;

  Future<void> loadThreads() async {
    _state = LoadState.loading;
    notifyListeners();
    try {
      final res = await ApiService.getThreads();
      final list = (res.data['data'] as List? ?? []);
      _threads = list
          .map((j) => ChatThread.fromJson(j as Map<String, dynamic>))
          .toList();
      _threads.sort((a, b) =>
          (b.lastMessageAt ?? DateTime(0))
              .compareTo(a.lastMessageAt ?? DateTime(0)));
      _totalUnread = _threads.fold(0, (sum, t) => sum + t.unreadCount);
      _state = LoadState.loaded;
      _subscribeToFirebaseEvents();
    } catch (e) {
      _state = LoadState.error;
      _errorMessage = 'Failed to load chats. Pull to refresh.';
      debugPrint('[ThreadsProvider] loadThreads error: $e');
    }
    notifyListeners();
  }

   /// Subscribe to Firebase events for real-time new-message signals.
  void _subscribeToFirebaseEvents() {
    final ctx = AuthService.instance.userContext;
    if (ctx == null) return;
    if (!ChatroomService.isFirebaseAvailable) {
      debugPrint('[ThreadsProvider] Firebase not available — skipping real-time events');
      return;
    }
    final schoolId = ctx.schoolId;
    final db = FirebaseDatabase.instance;

    for (final thread in _threads) {
      if (_firebaseListeners.containsKey(thread.id)) continue;
      final ref = db.ref('schools/$schoolId/threads/${thread.id}/events');
      final sub = ref.limitToLast(1).onChildAdded.listen((event) {
        // New message signal — reload thread list to get updated preview
        _refreshThread(thread.id);
      });
      _firebaseListeners[thread.id] = sub;
    }
  }

  Future<void> _refreshThread(String threadId) async {
    try {
      final res = await ApiService.getThreads();
      final list = (res.data['data'] as List? ?? []);
      final updated = list
          .map((j) => ChatThread.fromJson(j as Map<String, dynamic>))
          .toList();
      final idx = _threads.indexWhere((t) => t.id == threadId);
      final newThread = updated.firstWhere(
        (t) => t.id == threadId,
        orElse: () => _threads[idx],
      );
      if (idx >= 0) _threads[idx] = newThread;
      _threads.sort((a, b) =>
          (b.lastMessageAt ?? DateTime(0))
              .compareTo(a.lastMessageAt ?? DateTime(0)));
      _totalUnread = _threads.fold(0, (sum, t) => sum + t.unreadCount);
      notifyListeners();
    } catch (_) {}
  }

  void markThreadRead(String threadId) {
    final idx = _threads.indexWhere((t) => t.id == threadId);
    if (idx < 0) return;
    final prev = _threads[idx].unreadCount;
    _threads[idx] = _threads[idx].copyWith(unreadCount: 0);
    _totalUnread = (_totalUnread - prev).clamp(0, 9999);
    notifyListeners();
  }

  void addOrUpdateThread(ChatThread thread) {
    final idx = _threads.indexWhere((t) => t.id == thread.id);
    if (idx >= 0) {
      _threads[idx] = thread;
    } else {
      _threads.insert(0, thread);
    }
    _threads.sort((a, b) =>
        (b.lastMessageAt ?? DateTime(0))
            .compareTo(a.lastMessageAt ?? DateTime(0)));
    _totalUnread = _threads.fold(0, (sum, t) => sum + t.unreadCount);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _firebaseListeners.values) {
      sub.cancel();
    }
    _firebaseListeners.clear();
    super.dispose();
  }
}
