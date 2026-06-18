/// Hardcoded test users for the development shell.
/// These mirror what the real Netrack auth system would provide.
/// NEVER include this file in the production chatroom package.

class MockUser {
  final String id;
  final String name;
  final String role; // 'parent' | 'teacher' | 'student'
  final String schoolId;

  const MockUser({
    required this.id,
    required this.name,
    required this.role,
    required this.schoolId,
  });
}

class MockUsers {
  MockUsers._();

  static const String _schoolId = '00000000-0000-0000-0000-000000000001';

  static const List<MockUser> parents = [
    MockUser(
      id: '00000000-0000-0000-0001-000000000001',
      name: 'Jane Doe (Parent)',
      role: 'parent',
      schoolId: _schoolId,
    ),
    MockUser(
      id: '00000000-0000-0000-0001-000000000002',
      name: 'Mary Smith (Parent)',
      role: 'parent',
      schoolId: _schoolId,
    ),
    MockUser(
      id: '00000000-0000-0000-0001-000000000003',
      name: 'Robert Johnson (Parent)',
      role: 'parent',
      schoolId: _schoolId,
    ),
  ];

  static const List<MockUser> teachers = [
    MockUser(
      id: '00000000-0000-0000-0002-000000000001',
      name: 'David Mugisha (English Teacher)',
      role: 'teacher',
      schoolId: _schoolId,
    ),
    MockUser(
      id: '00000000-0000-0000-0002-000000000002',
      name: 'Sarah Uwimana (Math Teacher)',
      role: 'teacher',
      schoolId: _schoolId,
    ),
    MockUser(
      id: '00000000-0000-0000-0002-000000000003',
      name: 'Jean Pierre (Science Teacher)',
      role: 'teacher',
      schoolId: _schoolId,
    ),
  ];

  static const List<MockUser> students = [
    MockUser(
      id: '00000000-0000-0000-0003-000000000001',
      name: 'John Doe (Student)',
      role: 'student',
      schoolId: _schoolId,
    ),
    MockUser(
      id: '00000000-0000-0000-0003-000000000002',
      name: 'Alice Smith (Student)',
      role: 'student',
      schoolId: _schoolId,
    ),
  ];
}