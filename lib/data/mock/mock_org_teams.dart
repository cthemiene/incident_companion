/// Canonical organization IDs used across mock auth, scope, and teams flows.
const String mockOrgPlatformId = 'org-platform';
const String mockOrgAcmeId = 'org-acme';
const String mockOrgGlobalId = 'org-global';

/// Canonical team IDs used across mock incidents, users, and team settings.
const String mockTeamAdminId = 'team-admin';
const String mockTeamOpsId = 'team-ops';
const String mockTeamPaymentsId = 'team-payments';
const String mockTeamCoreId = 'team-core';

/// Immutable organization row used by team-directory screens and helpers.
class MockOrganization {
  const MockOrganization({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

/// Team row that keeps editable metadata separate from the canonical ID.
class MockTeamDefinition {
  const MockTeamDefinition({
    required this.id,
    required this.organizationId,
    required this.displayName,
    required this.description,
  });

  final String id;
  final String organizationId;
  final String displayName;
  final String description;

  /// Creates a modified team definition while preserving immutable IDs.
  MockTeamDefinition copyWith({String? displayName, String? description}) {
    return MockTeamDefinition(
      id: id,
      organizationId: organizationId,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
    );
  }
}

/// Centralized mock organization directory used by team management screens.
const List<MockOrganization> mockOrganizations = <MockOrganization>[
  MockOrganization(id: mockOrgPlatformId, displayName: 'Platform'),
  MockOrganization(id: mockOrgAcmeId, displayName: 'Acme'),
  MockOrganization(id: mockOrgGlobalId, displayName: 'Global'),
];

/// Immutable seed source for the mutable team directory.
const List<MockTeamDefinition> _seedMockTeams = <MockTeamDefinition>[
  MockTeamDefinition(
    id: mockTeamAdminId,
    organizationId: mockOrgPlatformId,
    displayName: 'Admin',
    description: 'Platform-wide administration and governance.',
  ),
  MockTeamDefinition(
    id: mockTeamOpsId,
    organizationId: mockOrgAcmeId,
    displayName: 'Ops',
    description: 'Core operations and incident response.',
  ),
  MockTeamDefinition(
    id: mockTeamPaymentsId,
    organizationId: mockOrgAcmeId,
    displayName: 'Payments',
    description: 'Payments platform ownership and support.',
  ),
  MockTeamDefinition(
    id: mockTeamCoreId,
    organizationId: mockOrgGlobalId,
    displayName: 'Core',
    description: 'Global shared services and edge platform.',
  ),
];

/// Mutable in-memory team directory used by the Teams page.
final List<MockTeamDefinition> _mockTeamDirectory =
    List<MockTeamDefinition>.from(_seedMockTeams);

/// Read-only team list for consumers that render team settings.
List<MockTeamDefinition> get mockTeamDefinitions =>
    List<MockTeamDefinition>.unmodifiable(_mockTeamDirectory);

/// Resolves a team definition by ID using case-insensitive lookup.
MockTeamDefinition? findMockTeamDefinitionById(String? teamId) {
  final normalizedId = teamId?.trim().toLowerCase();
  if (normalizedId == null || normalizedId.isEmpty) {
    return null;
  }
  for (final team in _mockTeamDirectory) {
    if (team.id.toLowerCase() == normalizedId) {
      return team;
    }
  }
  return null;
}

/// Returns organization display name from canonical ID, or falls back to ID.
String mockOrganizationLabel(String? organizationId) {
  final normalizedId = organizationId?.trim().toLowerCase();
  if (normalizedId == null || normalizedId.isEmpty) {
    return 'Unknown organization';
  }
  for (final organization in mockOrganizations) {
    if (organization.id.toLowerCase() == normalizedId) {
      return organization.displayName;
    }
  }
  return organizationId ?? 'Unknown organization';
}

/// Updates editable team metadata for team-management workflows.
bool updateMockTeamDefinition({
  required String teamId,
  required String displayName,
  required String description,
}) {
  final normalizedId = teamId.trim().toLowerCase();
  if (normalizedId.isEmpty) {
    return false;
  }
  final normalizedName = displayName.trim();
  final normalizedDescription = description.trim();
  if (normalizedName.isEmpty) {
    return false;
  }

  for (var index = 0; index < _mockTeamDirectory.length; index++) {
    final existing = _mockTeamDirectory[index];
    if (existing.id.toLowerCase() != normalizedId) {
      continue;
    }
    _mockTeamDirectory[index] = existing.copyWith(
      displayName: normalizedName,
      description: normalizedDescription.isEmpty
          ? existing.description
          : normalizedDescription,
    );
    return true;
  }
  return false;
}
