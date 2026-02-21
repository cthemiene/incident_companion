import '../models/incident.dart';
import 'mock_scope_data.dart';
import 'mock_users.dart';

/// Returns deterministic mock incidents used to seed local Hive data.
List<Incident> buildMockIncidents({required DateTime now}) {
  return List<Incident>.generate(_seedRows.length, (index) {
    final row = _seedRows[index];
    final createdAt = now.subtract(Duration(hours: (index + 1) * 4));
    final updatedAt = createdAt.add(Duration(minutes: (index % 4) * 20));
    final incidentNumber = index + 1;

    // Assign every 3rd incident to a rotating mock user.
    final assignedTo = index % 3 == 0
        ? mockUserEmails[index % mockUserEmails.length]
        : null;
    final assignedProfile = findMockUserProfileByEmail(assignedTo);
    final fallbackScope = seedFallbackScopeForIndex(index);

    return Incident(
      // Seed incidents use stable internal IDs and separate display numbers.
      id: 'seed-incident-$incidentNumber',
      incidentNumber: incidentNumber,
      title: 'Incident ${incidentNumber.toString().padLeft(3, '0')}',
      description:
          'Seeded incident for ${row.service} in ${row.environment.name}.',
      status: row.status,
      severity: row.severity,
      service: row.service,
      organizationId:
          assignedProfile?.organizationId ?? fallbackScope.organizationId,
      teamId: assignedProfile?.teamId ?? fallbackScope.teamId,
      environment: row.environment,
      createdAt: createdAt,
      updatedAt: updatedAt,
      assignedTo: assignedTo,
    );
  });
}

/// Small immutable row type to keep seed definitions readable.
class _IncidentSeedRow {
  const _IncidentSeedRow({
    required this.status,
    required this.severity,
    required this.service,
    required this.environment,
  });

  final IncidentStatus status;
  final IncidentSeverity severity;
  final String service;
  final IncidentEnvironment environment;
}

/// Centralized incident seed rows for repository initialization.
const List<_IncidentSeedRow> _seedRows = <_IncidentSeedRow>[
  _IncidentSeedRow(
    status: IncidentStatus.open,
    severity: IncidentSeverity.s1,
    service: 'Checkout API',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.inProgress,
    severity: IncidentSeverity.s2,
    service: 'Payments Gateway',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.resolved,
    severity: IncidentSeverity.s3,
    service: 'Auth Service',
    environment: IncidentEnvironment.nonProd,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.open,
    severity: IncidentSeverity.s4,
    service: 'Catalog Search',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.inProgress,
    severity: IncidentSeverity.s5,
    service: 'Notification Worker',
    environment: IncidentEnvironment.nonProd,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.resolved,
    severity: IncidentSeverity.s2,
    service: 'Mobile Backend',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.open,
    severity: IncidentSeverity.s1,
    service: 'Order Fulfillment',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.inProgress,
    severity: IncidentSeverity.s3,
    service: 'Inventory Sync',
    environment: IncidentEnvironment.nonProd,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.resolved,
    severity: IncidentSeverity.s4,
    service: 'Customer Portal',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.open,
    severity: IncidentSeverity.s5,
    service: 'Edge Proxy',
    environment: IncidentEnvironment.nonProd,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.inProgress,
    severity: IncidentSeverity.s1,
    service: 'Checkout API',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.resolved,
    severity: IncidentSeverity.s2,
    service: 'Payments Gateway',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.open,
    severity: IncidentSeverity.s3,
    service: 'Auth Service',
    environment: IncidentEnvironment.nonProd,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.inProgress,
    severity: IncidentSeverity.s4,
    service: 'Catalog Search',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.resolved,
    severity: IncidentSeverity.s5,
    service: 'Notification Worker',
    environment: IncidentEnvironment.nonProd,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.open,
    severity: IncidentSeverity.s1,
    service: 'Mobile Backend',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.inProgress,
    severity: IncidentSeverity.s2,
    service: 'Order Fulfillment',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.resolved,
    severity: IncidentSeverity.s3,
    service: 'Inventory Sync',
    environment: IncidentEnvironment.nonProd,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.open,
    severity: IncidentSeverity.s4,
    service: 'Customer Portal',
    environment: IncidentEnvironment.prod,
  ),
  _IncidentSeedRow(
    status: IncidentStatus.inProgress,
    severity: IncidentSeverity.s5,
    service: 'Edge Proxy',
    environment: IncidentEnvironment.nonProd,
  ),
];
