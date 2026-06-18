import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chatroom_service.dart';

class MessagesProvider extends ChangeNotifier {
  final String threadId;
  final String schoolId;

  MessagesProvider({required this.threadId, required this.schoolId});

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;
  bool _isTyping = false;
  String? _typingUser;
  StreamSubscription? _firebaseSub;
  StreamSubscription? _typingSub;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get isTyping => _isTyping;
  String? get typingUser => _typingUser;

  final _uuid = const Uuid();

  Future<void> loadMessages({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _messages.clear();
    }
    if (!_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = AuthService.instance.userContext?.userId ?? '';
      final res = await ApiService.getMessages(threadId, page: _page);
      final list = (res.data['data'] as List? ?? []);
      final fetched = list
          .map((j) => ChatMessage.fromJson(
                j as Map<String, dynamic>,
                currentUserId: currentUserId,
              ))
          .toList();

      if (fetched.isEmpty || fetched.length < 30) _hasMore = false;
      _messages.insertAll(0, fetched);
      _page++;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load messages. Tap to retry.';
      debugPrint('[MessagesProvider] loadMessages error: $e');
    }

    _isLoading = false;
    notifyListeners();
    _subscribeToFirebase();
  }

  void _subscribeToFirebase() {
    // Skip if Firebase was not initialized (firebaseOptions: null passed to ChatroomService)
    if (!ChatroomService.isFirebaseAvailable) return;

    _firebaseSub?.cancel();
    final db = FirebaseDatabase.instance;
    final ref = db.ref('schools/$schoolId/threads/$threadId/events');
    _firebaseSub = ref.limitToLast(1).onChildAdded.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final messageId = data['message_id'] as String?;
      if (messageId == null) return;
      if (_messages.any((m) => m.id == messageId)) return;
      _fetchNewMessage(messageId);
    });

    // Typing indicator
    _typingSub?.cancel();
    final typingRef = db.ref('schools/$schoolId/threads/$threadId/typing');
    _typingSub = typingRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final currentUserId = AuthService.instance.userContext?.userId ?? '';
      if (data == null) {
        _isTyping = false;
        _typingUser = null;
      } else {
        final others = data.entries
            .where((e) => e.key != currentUserId && e.value == true)
            .toList();
        _isTyping = others.isNotEmpty;
        _typingUser = others.isNotEmpty ? others.first.key as String : null;
      }
      notifyListeners();
    });
  }

  Future<void> _fetchNewMessage(String messageId) async {
    try {
      final currentUserId = AuthService.instance.userContext?.userId ?? '';
      final res = await ApiService.getMessages(threadId, page: 1);
      final list = (res.data['data'] as List? ?? []);
      for (final j in list) {
        final msg = ChatMessage.fromJson(
          j as Map<String, dynamic>,
          currentUserId: currentUserId,
        );
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages.add(msg);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Optimistically add message, then send to API.
  Future<void> sendTextMessage(String content) async {
    final ctx = AuthService.instance.userContext;
    if (ctx == null) {
      debugPrint('[MessagesProvider] sendTextMessage: userContext is null — cannot send');
      return;
    }

    final tempId = _uuid.v4();
    final optimistic = ChatMessage(
      id: tempId,
      schoolId: schoolId,
      threadId: threadId,
      senderId: ctx.userId,
      senderRole: ctx.role,
      messageType: MessageType.text,
      content: content,
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
      isMe: true,
      senderName: ctx.fullName,
    );
    _messages.add(optimistic);
    notifyListeners();

    try {
      final res = await ApiService.sendMessage({
        'thread_id': threadId,
        'message_type': 'text',
        'content': content,
      });
      final data = res.data['data'] as Map<String, dynamic>;
      final realId = data['id'] as String;
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx >= 0) {
        // Replace the optimistic message with the confirmed server message
        _messages[idx] = ChatMessage(
          id: realId,
          schoolId: schoolId,
          threadId: threadId,
          senderId: ctx.userId,
          senderRole: ctx.role,
          messageType: MessageType.text,
          content: content,
          sentAt: data['sent_at'] != null
              ? DateTime.tryParse(data['sent_at'] as String) ?? DateTime.now()
              : DateTime.now(),
          status: MessageStatus.sent,
          isMe: true,
          senderName: ctx.fullName,
        );
      }
    } catch (e) {
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(status: MessageStatus.failed);
      }
      debugPrint('[MessagesProvider] sendTextMessage error: $e');
    }
    notifyListeners();
  }

  Future<void> editMessage(String messageId, String newContent) async {
    try {
      await ApiService.editMessage(messageId, newContent);
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(
          content: newContent,
          isEdited: true,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessagesProvider] editMessage error: $e');
    }
  }

  Future<void> markSeen(String messageId) async {
    try {
      await ApiService.markSeen(messageId);
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx].copyWith(status: MessageStatus.seen);
        notifyListeners();
      }
    } catch (_) {}
  }

  void updateTypingStatus(bool isTyping) {
    if (!ChatroomService.isFirebaseAvailable) return;
    final ctx = AuthService.instance.userContext;
    if (ctx == null) return;
    final db = FirebaseDatabase.instance;
    db.ref('schools/$schoolId/threads/$threadId/typing/${ctx.userId}')
        .set(isTyping);
  }

  @override
  void dispose() {
    _firebaseSub?.cancel();
    _typingSub?.cancel();
    super.dispose();
  }
}
