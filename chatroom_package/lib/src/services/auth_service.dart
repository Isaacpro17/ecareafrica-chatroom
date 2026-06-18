import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_context.dart';

/// Manages JWT token and current user context within the chat package.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'netrack_chat_jwt';

  String? _token;
  UserContext? _userContext;

  String? get currentToken => _token;
  UserContext? get userContext => _userContext;
  bool get isAuthenticated => _token != null;

  /// Called by ChatroomWidget when the host app passes a JWT.
  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Restore token from secure storage on app restart.
  Future<void> restoreToken() async {
    _token = await _storage.read(key: _tokenKey);
  }

  void setUserContext(UserContext ctx) => _userContext = ctx;

  Future<void> clearSession() async {
    _token = null;
    _userContext = null;
    await _storage.delete(key: _tokenKey);
  }
}
