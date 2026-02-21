import 'dart:math';

import 'package:hive/hive.dart';

import '../local/hive_service.dart';
import '../models/incident.dart';
import '../models/incident_update.dart';
import 'incident_repository.dart';

/// Hive-backed mock repository used in place of a real backend.
class MockIncidentRepository implements IncidentRepository {
  MockIncidentRepository({HiveInterface? hive, this.pageSize = 10})
    : _hive = hive ?? Hive;

  static const String incidentsBoxName = HiveService.incidentsBoxName;
  static const String outboxBoxName = HiveService.outboxBoxName;

  final HiveInterface _hive;
  final int pageSize;
  Future<void>? _initFuture;

  Box<Incident> get _incidentsBox => _hive.box<Incident>(incidentsBoxName);
  Box<IncidentUpdate> get _outboxBox =>
      _hive.box<IncidentUpdate>(outboxBoxName);

  /// Loads incidents from local storage with filtering, search, and paging.
  @override
  Future<List<Incident>> getIncidents({
    Map<String, dynamic>? filters,
    String? search,
    int page = 1,
  }) async {
    await _ensureInitialized();
    var incidents = _incidentsBox.values.toList(growable: false);

    if (filters != null && filters.isNotEmpty) {
      incidents = incidents
          .where((incident) => _matchesFilters(incident, filters))
          .toList(growable: false);
    }

    if (search != null && search.trim().isNotEmpty) {
      final searchTerm = search.toLowerCase().trim();
      incidents = incidents
          .where((incident) => _matchesSearch(incident, searchTerm))
          .toList(growable: false);
    }

    incidents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final safePage = page < 1 ? 1 : page;
    final start = (safePage - 1) * pageSize;
    if (start >= incidents.length) {
      return <Incident>[];
    }
    final end = min(start + pageSize, incidents.length);
    return incidents.sublist(start, end);
  }

  /// Returns a single incident from the local incidents box.
  @override
  Future<Incident> getIncidentById(String id) async {
    await _ensureInitialized();
    final incident = _incidentsBox.get(id);
    if (incident == null) {
      throw StateError('Incident not found for id: $id');
    }
    return incident;
  }

  /// Persists an update in the local outbox queue.
  @override
  Future<void> queueUpdate(IncidentUpdate update) async {
    await _ensureInitialized();
    await _outboxBox.put(update.id, update);
  }

  /// Applies status/assignee changes immediately to local incident data.
  Future<void> applyUpdateLocally(IncidentUpdate update) async {
    await _ensureInitialized();
    final incident = _incidentsBox.get(update.incidentId);
    if (incident == null) {
      return;
    }

    final updatedIncident = incident.copyWith(
      status: update.newStatus ?? incident.status,
      updatedAt: update.createdAt,
      assignedTo: update.assignedTo,
      clearAssignedTo: update.assignedTo == null,
    );
    await _incidentsBox.put(incident.id, updatedIncident);
  }

  /// Returns queued updates sorted by creation time.
  @override
  Future<List<IncidentUpdate>> getOutbox() async {
    await _ensureInitialized();
    final outbox = _outboxBox.values.toList(growable: false);
    outbox.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return outbox;
  }

  /// Deletes a queued update from the local outbox.
  @override
  Future<void> deleteOutboxItem(String updateId) async {
    await _ensureInitialized();
    await _outboxBox.delete(updateId);
  }

  /// Ensures box initialization runs once and is awaited by all callers.
  Future<void> _ensureInitialized() {
    _initFuture ??= _initialize();
    return _initFuture!;
  }

  /// Opens boxes and seeds initial incidents when first run.
  Future<void> _initialize() async {
    registerIncidentAdapters();
    registerIncidentUpdateAdapters();

    if (!_hive.isBoxOpen(incidentsBoxName)) {
      await _hive.openBox<Incident>(incidentsBoxName);
    }
    if (!_hive.isBoxOpen(outboxBoxName)) {
      await _hive.openBox<IncidentUpdate>(outboxBoxName);
    }

    if (_incidentsBox.isEmpty) {
      final seedData = _seedIncidents();
      await _incidentsBox.putAll({
        for (final incident in seedData) incident.id: incident,
      });
    }
  }

  /// Applies key-based filter rules used by provider screens.
  bool _matchesFilters(Incident incident, Map<String, dynamic> filters) {
    final status = filters['status'];
    if (status != null && !_matchesEnum(incident.status.name, status)) {
      return false;
    }

    final severity = filters['severity'];
    if (severity != null && !_matchesEnum(incident.severity.name, severity)) {
      return false;
    }

    final environment = filters['environment'];
    if (environment != null &&
        !_matchesEnum(incident.environment.name, environment)) {
      return false;
    }

    final service = filters['service'];
    if (service is String &&
        service.trim().isNotEmpty &&
        incident.service.toLowerCase() != service.toLowerCase().trim()) {
      return false;
    }

    final assignedTo = filters['assignedTo'];
    if (assignedTo is String && assignedTo.trim().isNotEmpty) {
      final currentAssignee = incident.assignedTo?.toLowerCase();
      if (currentAssignee != assignedTo.toLowerCase().trim()) {
        return false;
      }
    }

    return true;
  }

  /// Performs case-insensitive text search across key incident fields.
  bool _matchesSearch(Incident incident, String searchTerm) {
    final haystack = [
      incident.id,
      incident.title,
      incident.description,
      incident.service,
      incident.status.name,
      incident.severity.name,
      incident.environment.name,
      incident.assignedTo ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(searchTerm);
  }

  /// Supports enum matching against single values and collections.
  bool _matchesEnum(String enumName, dynamic candidate) {
    if (candidate is Iterable) {
      for (final item in candidate) {
        if (_matchesEnum(enumName, item)) {
          return true;
        }
      }
      return false;
    }
    if (candidate is Enum) {
      return enumName == candidate.name;
    }
    if (candidate is String) {
      return enumName.toLowerCase() == candidate.trim().toLowerCase();
    }
    return false;
  }

  /// Generates deterministic demo incidents for local development.
  List<Incident> _seedIncidents() {
    final now = DateTime.now();
    const statuses = [
      IncidentStatus.open,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.open,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.open,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.open,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.open,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.open,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.open,
      IncidentStatus.inProgress,
    ];
    const severities = [
      IncidentSeverity.s1,
      IncidentSeverity.s2,
      IncidentSeverity.s3,
      IncidentSeverity.s4,
      IncidentSeverity.s5,
      IncidentSeverity.s2,
      IncidentSeverity.s1,
      IncidentSeverity.s3,
      IncidentSeverity.s4,
      IncidentSeverity.s5,
      IncidentSeverity.s1,
      IncidentSeverity.s2,
      IncidentSeverity.s3,
      IncidentSeverity.s4,
      IncidentSeverity.s5,
      IncidentSeverity.s1,
      IncidentSeverity.s2,
      IncidentSeverity.s3,
      IncidentSeverity.s4,
      IncidentSeverity.s5,
    ];
    const services = [
      'Checkout API',
      'Payments Gateway',
      'Auth Service',
      'Catalog Search',
      'Notification Worker',
      'Mobile Backend',
      'Order Fulfillment',
      'Inventory Sync',
      'Customer Portal',
      'Edge Proxy',
      'Checkout API',
      'Payments Gateway',
      'Auth Service',
      'Catalog Search',
      'Notification Worker',
      'Mobile Backend',
      'Order Fulfillment',
      'Inventory Sync',
      'Customer Portal',
      'Edge Proxy',
    ];
    const environments = [
      IncidentEnvironment.prod,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
      IncidentEnvironment.prod,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
      IncidentEnvironment.prod,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
      IncidentEnvironment.prod,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
      IncidentEnvironment.prod,
      IncidentEnvironment.nonProd,
    ];

    return List<Incident>.generate(20, (index) {
      final createdAt = now.subtract(Duration(hours: (index + 1) * 4));
      final updatedAt = createdAt.add(Duration(minutes: (index % 4) * 20));
      final idNumber = (index + 1).toString().padLeft(3, '0');

      return Incident(
        id: 'INC-$idNumber',
        title: 'Incident $idNumber',
        description:
            'Seeded incident for ${services[index]} in ${environments[index].name}.',
        status: statuses[index],
        severity: severities[index],
        service: services[index],
        environment: environments[index],
        createdAt: createdAt,
        updatedAt: updatedAt,
        assignedTo: index % 3 == 0
            ? 'engineer${(index % 5) + 1}@example.com'
            : null,
      );
    });
  }
}
