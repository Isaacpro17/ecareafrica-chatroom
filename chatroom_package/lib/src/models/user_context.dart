/// User context models — mirrors the user-context bridge API response.

class TeacherContact {
  final String teacherId;
  final String userId;
  final String fullName;
  final String subject;
  final bool isOnline;
  final DateTime? lastSeen;

  const TeacherContact({
    required this.teacherId,
    required this.userId,
    required this.fullName,
    required this.subject,
    this.isOnline = false,
    this.lastSeen,
  });

  factory TeacherContact.fromJson(Map<String, dynamic> json) => TeacherContact(
    teacherId: json['teacher_id'] as String,
    userId: json['user_id'] as String,
    fullName: json['full_name'] as String,
    subject: json['subject'] as String,
    isOnline: json['is_online'] as bool? ?? false,
    lastSeen: json['last_seen'] != null
        ? DateTime.tryParse(json['last_seen'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'teacher_id': teacherId,
    'user_id': userId,
    'full_name': fullName,
    'subject': subject,
    'is_online': isOnline,
    'last_seen': lastSeen?.toIso8601String(),
  };
}

class StudentInfo {
  final String studentId;
  final String fullName;
  final String classId;
  final String section;
  final String admissionNumber;
  final List<String> parentIds;

  const StudentInfo({
    required this.studentId,
    required this.fullName,
    required this.classId,
    required this.section,
    required this.admissionNumber,
    required this.parentIds,
  });

  factory StudentInfo.fromJson(Map<String, dynamic> json) => StudentInfo(
    studentId: json['student_id'] as String,
    fullName: json['full_name'] as String,
    classId: json['class_id'] as String,
    section: json['section'] as String,
    admissionNumber: json['admission_number'] as String,
    parentIds: List<String>.from(json['parent_ids'] as List? ?? []),
  );
}

class ChildInfo {
  final String studentId;
  final String fullName;
  final String classId;
  final String section;
  final List<TeacherContact> teachers;

  const ChildInfo({
    required this.studentId,
    required this.fullName,
    required this.classId,
    required this.section,
    required this.teachers,
  });

  factory ChildInfo.fromJson(Map<String, dynamic> json) => ChildInfo(
    studentId: json['student_id'] as String,
    fullName: json['full_name'] as String,
    classId: json['class_id'] as String,
    section: json['section'] as String,
    teachers: (json['teachers'] as List? ?? [])
        .map((t) => TeacherContact.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

/// Resolved user context — returned by the bridge and cached for 30 minutes.
class UserContext {
  final String userId;
  final String schoolId;
  final String role; // 'parent' | 'teacher' | 'student'
  final String fullName;

  // Parent-specific
  final List<ChildInfo> children;

  // Teacher-specific
  final List<String> subjects;
  final List<Map<String, dynamic>> classes;

  // Student-specific
  final String? studentId;
  final String? admissionNumber;
  final String? classId;
  final String? section;
  final List<TeacherContact> teachers;

  const UserContext({
    required this.userId,
    required this.schoolId,
    required this.role,
    required this.fullName,
    this.children = const [],
    this.subjects = const [],
    this.classes = const [],
    this.studentId,
    this.admissionNumber,
    this.classId,
    this.section,
    this.teachers = const [],
  });

  factory UserContext.fromJson(Map<String, dynamic> json) => UserContext(
    userId: json['user_id'] as String? ?? json['student_id'] as String,
    schoolId: json['school_id'] as String,
    role: json['role'] as String,
    fullName: json['full_name'] as String,
    children: (json['children'] as List? ?? [])
        .map((c) => ChildInfo.fromJson(c as Map<String, dynamic>))
        .toList(),
    subjects: List<String>.from(json['subjects'] as List? ?? []),
    classes: List<Map<String, dynamic>>.from(json['classes'] as List? ?? []),
    studentId: json['student_id'] as String?,
    admissionNumber: json['admission_number'] as String?,
    classId: json['class_id'] as String?,
    section: json['section'] as String?,
    teachers: (json['teachers'] as List? ?? [])
        .map((t) => TeacherContact.fromJson(t as Map<String, dynamic>))
        .toList(),
  );

  bool get isParent  => role == 'parent';
  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
}
