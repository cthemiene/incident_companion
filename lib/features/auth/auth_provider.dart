import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/hive_service.dart';

/// Session state for mock authentication and current-user identity.
class AuthProvider extends ChangeNotifier {
  AuthProvider({Uuid? uuid}) : _uuid = uuid ?? const Uuid() {
    _restoreSession();
  }

  static const String _tokenKey = 'mock_token';
  static const String _userKey = 'mock_user';
  static const String _defaultUserEmail = 'engineer1@example.com';

  final Uuid _uuid;

  bool _isAuthenticated = false;
  String? _mockToken;
  String? _currentUserEmail;

  bool get isAuthenticated => _isAuthenticated;
  String? get mockToken => _mockToken;
  String? get currentUserEmail => _currentUserEmail;

  /// Creates a mock session token and persists user identity.
  Future<void> signIn() async {
    final token = 'mock_${_uuid.v4()}';
    const userEmail = _defaultUserEmail;
    await HiveService.authBox.put(_tokenKey, token);
    await HiveService.authBox.put(_userKey, userEmail);
    _mockToken = token;
    _currentUserEmail = userEmail;
    _isAuthenticated = true;
    notifyListeners();
  }

  /// Clears persisted auth state and in-memory session values.
  Future<void> signOut() async {
    await HiveService.authBox.delete(_tokenKey);
    await HiveService.authBox.delete(_userKey);
    _mockToken = null;
    _currentUserEmail = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Restores session values from local storage on app startup.
  void _restoreSession() {
    final storedToken = HiveService.authBox.get(_tokenKey);
    final storedUser = HiveService.authBox.get(_userKey);
    _mockToken = storedToken;
    _currentUserEmail = storedUser;
    _isAuthenticated = storedToken != null && storedToken.isNotEmpty;
  }
}
