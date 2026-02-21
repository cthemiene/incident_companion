import 'mock_org_teams.dart';
import '../../shared/utils/user_role.dart';

/// Lightweight mock user profile used for role and scope behaviors.
class MockUserProfile {
  const MockUserProfile({
    required this.email,
    required this.role,
    required this.organizationId,
    required this.teamId,
  });

  final String email;
  final UserRole role;
  final String organizationId;
  final String teamId;

  /// Creates a modified copy used when admin updates directory entries.
  MockUserProfile copyWith({
    String? email,
    UserRole? role,
    String? organizationId,
    String? teamId,
  }) {
    return MockUserProfile(
      email: email ?? this.email,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      teamId: teamId ?? this.teamId,
    );
  }
}

/// Default mock user used for sign-in and "assigned to me" behavior.
const String defaultMockUserEmail = 'engineer1@example.com';

/// Immutable seed list that boots the mutable in-memory directory.
const List<MockUserProfile> _seedMockUserProfiles = <MockUserProfile>[
  MockUserProfile(
    email: 'admin1@example.com',
    role: UserRole.admin,
    organizationId: mockOrgPlatformId,
    teamId: mockTeamAdminId,
  ),
  MockUserProfile(
    email: 'manager1@example.com',
    role: UserRole.manager,
    organizationId: mockOrgAcmeId,
    teamId: mockTeamOpsId,
  ),
  MockUserProfile(
    email: 'engineer1@example.com',
    role: UserRole.member,
    organizationId: mockOrgAcmeId,
    teamId: mockTeamOpsId,
  ),
  MockUserProfile(
    email: 'engineer2@example.com',
    role: UserRole.member,
    organizationId: mockOrgAcmeId,
    teamId: mockTeamOpsId,
  ),
  MockUserProfile(
    email: 'engineer3@example.com',
    role: UserRole.member,
    organizationId: mockOrgAcmeId,
    teamId: mockTeamPaymentsId,
  ),
  MockUserProfile(
    email: 'engineer4@example.com',
    role: UserRole.member,
    organizationId: mockOrgGlobalId,
    teamId: mockTeamCoreId,
  ),
  MockUserProfile(
    email: 'engineer5@example.com',
    role: UserRole.member,
    organizationId: mockOrgGlobalId,
    teamId: mockTeamCoreId,
  ),
];

/// Mutable in-memory directory used by profile editing and selectors.
final List<MockUserProfile> _mockUserDirectory = List<MockUserProfile>.from(
  _seedMockUserProfiles,
);

/// Centralized mock user directory for auth, assignment, and scope checks.
List<MockUserProfile> get mockUserProfiles =>
    List<MockUserProfile>.unmodifiable(_mockUserDirectory);

/// Convenience email list for selectors that only need user identities.
List<String> get mockUserEmails => List<String>.unmodifiable(
  _mockUserDirectory.map((profile) => profile.email),
);

/// Looks up a mock profile by email using case-insensitive comparison.
MockUserProfile? findMockUserProfileByEmail(String? email) {
  final normalizedEmail = email?.trim().toLowerCase();
  if (normalizedEmail == null || normalizedEmail.isEmpty) {
    return null;
  }
  for (final profile in _mockUserDirectory) {
    if (profile.email.toLowerCase() == normalizedEmail) {
      return profile;
    }
  }
  return null;
}

/// Returns an existing profile or falls back to the default member profile.
MockUserProfile defaultMockUserProfile([String? email]) {
  final matched = findMockUserProfileByEmail(email);
  if (matched != null) {
    return matched;
  }
  return _mockUserDirectory.firstWhere(
    (profile) => profile.email == defaultMockUserEmail,
    orElse: () => _seedMockUserProfiles.first,
  );
}

/// Returns users in a single organization with optional current-user exclusion.
List<MockUserProfile> getOrganizationMembers({
  required String? organizationId,
  String? excludeEmail,
}) {
  final normalizedOrg = organizationId?.trim().toLowerCase();
  if (normalizedOrg == null || normalizedOrg.isEmpty) {
    return const <MockUserProfile>[];
  }
  final normalizedExclude = excludeEmail?.trim().toLowerCase();
  final members = <MockUserProfile>[];
  for (final profile in _mockUserDirectory) {
    final inOrg = profile.organizationId.trim().toLowerCase() == normalizedOrg;
    final isExcluded =
        normalizedExclude != null &&
        profile.email.trim().toLowerCase() == normalizedExclude;
    if (inOrg && !isExcluded) {
      members.add(profile);
    }
  }
  members.sort((a, b) {
    final roleComparison = _roleSortOrder(
      a.role,
    ).compareTo(_roleSortOrder(b.role));
    if (roleComparison != 0) {
      return roleComparison;
    }
    return a.email.toLowerCase().compareTo(b.email.toLowerCase());
  });
  return members;
}

/// Updates an existing directory profile by email and returns success state.
bool updateMockUserProfileByEmail({
  required String email,
  UserRole? role,
  String? organizationId,
  String? teamId,
}) {
  final normalizedEmail = email.trim().toLowerCase();
  if (normalizedEmail.isEmpty) {
    return false;
  }
  for (var index = 0; index < _mockUserDirectory.length; index++) {
    final existing = _mockUserDirectory[index];
    if (existing.email.toLowerCase() != normalizedEmail) {
      continue;
    }
    _mockUserDirectory[index] = existing.copyWith(
      role: role,
      organizationId: _normalizeRequiredValue(
        organizationId,
        existing.organizationId,
      ),
      teamId: _normalizeRequiredValue(teamId, existing.teamId),
    );
    return true;
  }
  return false;
}

/// Maps role priority so org charts show leadership before members.
int _roleSortOrder(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 0;
    case UserRole.manager:
      return 1;
    case UserRole.member:
      return 2;
  }
}

/// Normalizes editable values while preserving previous required fields.
String _normalizeRequiredValue(String? value, String fallback) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallback;
  }
  return trimmed;
}
