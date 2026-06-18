/// Chat message model — maps to chat_messages table.

enum MessageType { text, image, document, voice, system }
enum MessageStatus { composing, sending, sent, delivered, seen, failed, retrying }

class ChatMessage {
  final String id;
  final String schoolId;
  final String threadId;
  final String senderId;
  final String senderRole;
  final MessageType messageType;
  final String? content;
  final String? mediaLocalRef;
  final String? mediaType;
  final int? mediaSizeBytes;
  final String? originalFilename;
  final bool isBroadcast;
  final String? broadcastId;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime sentAt;
  MessageStatus status;

  // Local-only fields (not persisted)
  final bool isMe;
  final String senderName;

  ChatMessage({
    required this.id,
    required this.schoolId,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    required this.messageType,
    this.content,
    this.mediaLocalRef,
    this.mediaType,
    this.mediaSizeBytes,
    this.originalFilename,
    this.isBroadcast = false,
    this.broadcastId,
    this.isEdited = false,
    this.editedAt,
    required this.sentAt,
    this.status = MessageStatus.sent,
    required this.isMe,
    required this.senderName,
  });

  bool get isText  => messageType == MessageType.text;
  bool get isImage => messageType == MessageType.image;
  bool get isDoc   => messageType == MessageType.document;
  bool get isVoice => messageType == MessageType.voice;
  bool get isSystem=> messageType == MessageType.system;

  /// Whether the message is still within the 5-minute edit window.
  bool get canEdit {
    if (!isMe || !isText) return false;
    return DateTime.now().difference(sentAt).inMinutes < 5;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {
    required String currentUserId,
  }) => ChatMessage(
    id: json['id'] as String,
    schoolId: json['school_id'] as String,
    threadId: json['thread_id'] as String,
    senderId: json['sender_id'] as String,
    senderRole: json['sender_role'] as String,
    messageType: _parseType(json['message_type'] as String),
    content: json['content'] as String?,
    mediaLocalRef: json['media_local_ref'] as String?,
    mediaType: json['media_type'] as String?,
    mediaSizeBytes: json['media_size_bytes'] as int?,
    originalFilename: json['original_filename'] as String?,
    isBroadcast: json['is_broadcast'] as bool? ?? false,
    broadcastId: json['broadcast_id'] as String?,
    isEdited: json['is_edited'] as bool? ?? false,
    editedAt: json['edited_at'] != null
        ? DateTime.tryParse(json['edited_at'] as String)
        : null,
    sentAt: DateTime.parse(json['sent_at'] as String),
    status: _parseStatus(json['status'] as String? ?? 'sent'),
    isMe: json['sender_id'] == currentUserId,
    senderName: json['sender_name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'school_id': schoolId,
    'thread_id': threadId,
    'sender_id': senderId,
    'sender_role': senderRole,
    'message_type': messageType.name,
    'content': content,
    'media_local_ref': mediaLocalRef,
    'media_type': mediaType,
    'media_size_bytes': mediaSizeBytes,
    'original_filename': originalFilename,
    'is_broadcast': isBroadcast,
    'broadcast_id': broadcastId,
    'is_edited': isEdited,
    'edited_at': editedAt?.toIso8601String(),
    'sent_at': sentAt.toIso8601String(),
    'status': status.name,
  };

  static MessageType _parseType(String t) => switch (t) {
    'image'    => MessageType.image,
    'document' => MessageType.document,
    'voice'    => MessageType.voice,
    'system'   => MessageType.system,
    _          => MessageType.text,
  };

  static MessageStatus _parseStatus(String s) => switch (s) {
    'sending'   => MessageStatus.sending,
    'delivered' => MessageStatus.delivered,
    'seen'      => MessageStatus.seen,
    'failed'    => MessageStatus.failed,
    'retrying'  => MessageStatus.retrying,
    _           => MessageStatus.sent,
  };

  ChatMessage copyWith({MessageStatus? status, bool? isEdited, String? content}) =>
    ChatMessage(
      id: id, schoolId: schoolId, threadId: threadId,
      senderId: senderId, senderRole: senderRole,
      messageType: messageType, content: content ?? this.content,
      mediaLocalRef: mediaLocalRef, mediaType: mediaType,
      mediaSizeBytes: mediaSizeBytes, originalFilename: originalFilename,
      isBroadcast: isBroadcast, broadcastId: broadcastId,
      isEdited: isEdited ?? this.isEdited, editedAt: editedAt,
      sentAt: sentAt, status: status ?? this.status,
      isMe: isMe, senderName: senderName,
    );
}
