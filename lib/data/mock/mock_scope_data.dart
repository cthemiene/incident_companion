import 'mock_org_teams.dart';
import 'mock_users.dart';

/// Default placeholder organization used for legacy records.
const String defaultMockOrganizationId = 'org-default';

/// Default placeholder team used for legacy records.
const String defaultMockTeamId = 'team-default';

/// Simple org/team container for mock scope resolution.
class MockScope {
  const MockScope({required this.organizationId, required this.teamId});

  final String organizationId;
  final String teamId;
}

/// Common reusable org/team scope values used across mock flows.
const MockScope mockAcmeOpsScope = MockScope(
  // Uses centralized IDs from mock_org_teams.dart for consistency.
  organizationId: mockOrgAcmeId,
  teamId: mockTeamOpsId,
);
const MockScope mockAcmePaymentsScope = MockScope(
  organizationId: mockOrgAcmeId,
  teamId: mockTeamPaymentsId,
);
const MockScope mockGlobalCoreScope = MockScope(
  organizationId: mockOrgGlobalId,
  teamId: mockTeamCoreId,
);

/// Detects records that still carry placeholder scope values.
bool isLegacyUnscopedIncident({
  required String organizationId,
  required String teamId,
}) {
  return organizationId == defaultMockOrganizationId ||
      teamId == defaultMockTeamId;
}

/// Returns deterministic fallback scope used by seed incident generation.
MockScope seedFallbackScopeForIndex(int index) {
  if (index.isEven) {
    return index % 4 == 0 ? mockAcmeOpsScope : mockAcmePaymentsScope;
  }
  return mockGlobalCoreScope;
}

/// Infers incident scope from assignee first, then service keywords.
MockScope inferMockIncidentScope({
  required String service,
  String? assignedTo,
}) {
  final assignedProfile = findMockUserProfileByEmail(assignedTo);
  if (assignedProfile != null) {
    return MockScope(
      organizationId: assignedProfile.organizationId,
      teamId: assignedProfile.teamId,
    );
  }

  final normalizedService = service.toLowerCase();
  if (normalizedService.contains('payment') ||
      normalizedService.contains('checkout')) {
    return mockAcmePaymentsScope;
  }
  if (normalizedService.contains('order') ||
      normalizedService.contains('mobile')) {
    return mockAcmeOpsScope;
  }
  if (normalizedService.contains('inventory') ||
      normalizedService.contains('customer') ||
      normalizedService.contains('edge')) {
    return mockGlobalCoreScope;
  }

  // Keeps unknown services in a stable default scope.
  return mockAcmeOpsScope;
}
