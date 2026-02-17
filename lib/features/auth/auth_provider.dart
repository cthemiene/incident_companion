import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/hive_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({Uuid? uuid}) : _uuid = uuid ?? const Uuid() {
    _restoreSession();
  }

  static const String _tokenKey = 'mock_token';

  final Uuid _uuid;

  bool _isAuthenticated = false;
  String? _mockToken;

  bool get isAuthenticated => _isAuthenticated;
  String? get mockToken => _mockToken;

  Future<void> signIn() async {
    final token = 'mock_${_uuid.v4()}';
    await HiveService.authBox.put(_tokenKey, token);
    _mockToken = token;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await HiveService.authBox.delete(_tokenKey);
    _mockToken = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void _restoreSession() {
    final storedToken = HiveService.authBox.get(_tokenKey);
    _mockToken = storedToken;
    _isAuthenticated = storedToken != null && storedToken.isNotEmpty;
  }
}
