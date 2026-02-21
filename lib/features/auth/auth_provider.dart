import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/hive_service.dart';
import '../../data/mock/mock_org_teams.dart';
import '../../data/mock/mock_users.dart';
import '../../shared/utils/user_role.dart';

/// Session state for mock authentication and current-user identity.
class AuthProvider extends ChangeNotifier {
  AuthProvider({Uuid? uuid}) : _uuid = uuid ?? const Uuid() {
    _restoreSession();
  }

  static const String _tokenKey = 'mock_token';
  static const String _userKey = 'mock_user';
  static const String _roleKey = 'mock_role';
  static const String _organizationKey = 'mock_organization';
  static const String _teamKey = 'mock_team';

  final Uuid _uuid;

  bool _isAuthenticated = false;
  String? _mockToken;
  String? _currentUserEmail;
  UserRole _currentUserRole = UserRole.member;
  String? _currentOrganizationId;
  String? _currentTeamId;

  bool get isAuthenticated => _isAuthenticated;
  String? get mockToken => _mockToken;
  String? get currentUserEmail => _currentUserEmail;
  UserRole get currentUserRole => _currentUserRole;
  String? get currentOrganizationId => _currentOrganizationId;
  String? get currentTeamId => _currentTeamId;

  /// Creates a mock session token and persists role/scope identity.
  Future<void> signIn({String? email}) async {
    final token = 'mock_${_uuid.v4()}';
    final profile = defaultMockUserProfile(email);
    final userEmail = profile.email;
    await HiveService.authBox.put(_tokenKey, token);
    await HiveService.authBox.put(_userKey, userEmail);
    await HiveService.authBox.put(_roleKey, profile.role.storageValue);
    await HiveService.authBox.put(_organizationKey, profile.organizationId);
    await HiveService.authBox.put(_teamKey, profile.teamId);
    _mockToken = token;
    _currentUserEmail = userEmail;
    _currentUserRole = profile.role;
    _currentOrganizationId = profile.organizationId;
    _currentTeamId = profile.teamId;
    _isAuthenticated = true;
    notifyListeners();
  }

  /// Clears persisted auth state and in-memory session values.
  Future<void> signOut() async {
    await HiveService.authBox.delete(_tokenKey);
    await HiveService.authBox.delete(_userKey);
    await HiveService.authBox.delete(_roleKey);
    await HiveService.authBox.delete(_organizationKey);
    await HiveService.authBox.delete(_teamKey);
    _mockToken = null;
    _currentUserEmail = null;
    _currentUserRole = UserRole.member;
    _currentOrganizationId = null;
    _currentTeamId = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Updates the current signed-in profile with role-based edit permissions.
  ///
  /// Permission rules:
  /// - Admin: may update email, role, organization, and team.
  /// - Manager/Member: read-only; no values are changed.
  Future<void> updateCurrentUserProfile({
    String? email,
    UserRole? role,
    String? organizationId,
    String? teamId,
  }) async {
    if (!_isAuthenticated) {
      return;
    }

    final canEditAll = _currentUserRole == UserRole.admin;
    if (!canEditAll) {
      return;
    }

    // Normalizes text values so persisted profile data remains consistent.
    String? normalizeValue(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    final nextEmail = canEditAll
        ? normalizeValue(email) ?? _currentUserEmail
        : _currentUserEmail;
    final nextRole = canEditAll ? role ?? _currentUserRole : _currentUserRole;
    final nextOrganizationId = canEditAll
        ? normalizeValue(organizationId) ?? _currentOrganizationId
        : _currentOrganizationId;
    final nextTeamId = canEditAll
        ? normalizeValue(teamId) ?? _currentTeamId
        : _currentTeamId;

    _currentUserEmail = nextEmail;
    _currentUserRole = nextRole;
    _currentOrganizationId = nextOrganizationId;
    _currentTeamId = nextTeamId;

    // Persists nullable profile fields without introducing empty-string values.
    Future<void> persistNullableValue(String key, String? value) async {
      if (value == null) {
        await HiveService.authBox.delete(key);
        return;
      }
      await HiveService.authBox.put(key, value);
    }

    await persistNullableValue(_userKey, _currentUserEmail);
    await HiveService.authBox.put(_roleKey, _currentUserRole.storageValue);
    await persistNullableValue(_organizationKey, _currentOrganizationId);
    await persistNullableValue(_teamKey, _currentTeamId);
    notifyListeners();
  }

  /// Restores session values from local storage on app startup.
  void _restoreSession() {
    final storedToken = HiveService.authBox.get(_tokenKey);
    final storedUser = HiveService.authBox.get(_userKey);
    final storedRole = HiveService.authBox.get(_roleKey);
    final storedOrganization = HiveService.authBox.get(_organizationKey);
    final storedTeam = HiveService.authBox.get(_teamKey);
    final hasValidToken = storedToken != null && storedToken.isNotEmpty;
    _isAuthenticated = hasValidToken;
    if (!hasValidToken) {
      // Keeps providers in a clean signed-out state at cold start.
      _mockToken = null;
      _currentUserEmail = null;
      _currentUserRole = UserRole.member;
      _currentOrganizationId = null;
      _currentTeamId = null;
      return;
    }

    final profile = defaultMockUserProfile(storedUser);
    final normalizedStoredOrganization = _normalizeLegacyOrganizationId(
      storedOrganization,
    );
    _mockToken = storedToken;
    _currentUserEmail = storedUser ?? profile.email;
    _currentUserRole = storedRole == null
        ? profile.role
        : UserRoleStorage.fromStorage(storedRole);
    _currentOrganizationId =
        normalizedStoredOrganization ?? profile.organizationId;
    _currentTeamId = storedTeam ?? profile.teamId;
  }

  /// Normalizes legacy organization IDs to the current canonical identifier.
  String? _normalizeLegacyOrganizationId(String? organizationId) {
    final trimmed = organizationId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.toLowerCase() == 'org-globo') {
      return mockOrgGlobalId;
    }
    return trimmed;
  }
}
