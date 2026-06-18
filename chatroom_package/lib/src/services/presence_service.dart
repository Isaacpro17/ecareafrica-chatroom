import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Manages real-time online/offline presence via Firebase Realtime Database.
/// Heartbeat syncs to SQL every 30 seconds.
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _heartbeatTimer;
  final Map<String, StreamSubscription> _presenceListeners = {};

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
  );

  /// Start broadcasting this user's presence.
  Future<void> goOnline(String schoolId, String userId) async {
    final ref = _db.ref('schools/$schoolId/presence/$userId');

    // Write online status
    await ref.set({'is_online': true, 'last_seen': ServerValue.timestamp});

    // Auto-write offline on disconnect
    await ref.onDisconnect().set({
      'is_online': false,
      'last_seen': ServerValue.timestamp,
    });

    // Start heartbeat to sync SQL table
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        await ApiService.heartbeat();
      } catch (e) {
        debugPrint('[PresenceService] Heartbeat failed: $e');
      }
    });
  }

  /// Stop broadcasting presence (app backgrounded / closed).
  Future<void> goOffline(String schoolId, String userId) async {
    _heartbeatTimer?.cancel();
    final ref = _db.ref('schools/$schoolId/presence/$userId');
    await ref.set({'is_online': false, 'last_seen': ServerValue.timestamp});
  }

  /// Listen to another user's presence and call [onUpdate] with (isOnline, lastSeen).
  StreamSubscription listenToPresence(
    String schoolId,
    String userId,
    void Function(bool isOnline, DateTime? lastSeen) onUpdate,
  ) {
    final ref = _db.ref('schools/$schoolId/presence/$userId');
    final sub = ref.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final isOnline = data['is_online'] as bool? ?? false;
      final ts = data['last_seen'];
      DateTime? lastSeen;
      if (ts is int) lastSeen = DateTime.fromMillisecondsSinceEpoch(ts);
      onUpdate(isOnline, lastSeen);
    });
    _presenceListeners[userId] = sub;
    return sub;
  }

  void cancelPresenceListener(String userId) {
    _presenceListeners[userId]?.cancel();
    _presenceListeners.remove(userId);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    for (final sub in _presenceListeners.values) {
      sub.cancel();
    }
    _presenceListeners.clear();
  }
}
