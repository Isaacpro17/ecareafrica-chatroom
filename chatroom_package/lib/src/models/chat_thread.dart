/// Chat thread model — maps to chat_threads table.

enum ThreadType { direct, broadcast }
enum ThreadInitiator { parent, student }

class ChatThread {
  final String id;
  final String schoolId;
  final ThreadType threadType;
  final ThreadInitiator threadInitiator;
  final String? parentId;
  final String teacherId;
  final String studentId;
  final String? classId;
  final String? broadcastId;
  final DateTime? lastMessageAt;
  final String status;

  // Resolved display fields (from user-context cache)
  final String displayName;      // e.g. "David — English Teacher"
  final String? subjectLabel;
  final String? lastMessagePreview;
  final int unreadCount;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? avatarUrl;

  const ChatThread({
    required this.id,
    required this.schoolId,
    required this.threadType,
    required this.threadInitiator,
    this.parentId,
    required this.teacherId,
    required this.studentId,
    this.classId,
    this.broadcastId,
    this.lastMessageAt,
    this.status = 'active',
    required this.displayName,
    this.subjectLabel,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.isOnline = false,
    this.lastSeen,
    this.avatarUrl,
  });

  bool get isBroadcast => threadType == ThreadType.broadcast;

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id'] as String,
    schoolId: json['school_id'] as String,
    threadType: json['thread_type'] == 'broadcast'
        ? ThreadType.broadcast
        : ThreadType.direct,
    threadInitiator: json['thread_initiator'] == 'student'
        ? ThreadInitiator.student
        : ThreadInitiator.parent,
    parentId: json['parent_id'] as String?,
    teacherId: json['teacher_id'] as String,
    studentId: json['student_id'] as String,
    classId: json['class_id'] as String?,
    broadcastId: json['broadcast_id'] as String?,
    lastMessageAt: json['last_message_at'] != null
        ? DateTime.tryParse(json['last_message_at'].toString())
        : null,
    status: json['status'] as String? ?? 'active',
    displayName: json['display_name'] as String? ?? '',
    subjectLabel: json['subject_label'] as String?,
    lastMessagePreview: json['last_message_preview'] as String?,
    unreadCount: json['unread_count'] != null
        ? int.tryParse(json['unread_count'].toString()) ?? 0
        : 0,
    isOnline: json['is_online'] as bool? ?? false,
    lastSeen: json['last_seen_at'] != null
        ? DateTime.tryParse(json['last_seen_at'].toString())
        : null,
    avatarUrl: json['avatar_url'] as String?,
  );
  ChatThread copyWith({
    int? unreadCount,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    bool? isOnline,
    DateTime? lastSeen,
  }) => ChatThread(
    id: id,
    schoolId: schoolId,
    threadType: threadType,
    threadInitiator: threadInitiator,
    parentId: parentId,
    teacherId: teacherId,
    studentId: studentId,
    classId: classId,
    broadcastId: broadcastId,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    status: status,
    displayName: displayName,
    subjectLabel: subjectLabel,
    lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    unreadCount: unreadCount ?? this.unreadCount,
    isOnline: isOnline ?? this.isOnline,
    lastSeen: lastSeen ?? this.lastSeen,
    avatarUrl: avatarUrl,
  );
}
