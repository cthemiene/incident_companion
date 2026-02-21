import 'dart:math';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../local/hive_service.dart';
import '../mock/mock_incident_seed.dart';
import '../models/incident.dart';
import '../models/incident_update.dart';
import 'incident_repository.dart';

/// Hive-backed mock repository used in place of a real backend.
class MockIncidentRepository implements IncidentRepository {
  MockIncidentRepository({HiveInterface? hive, this.pageSize = 10})
    : _hive = hive ?? Hive;

  static const String incidentsBoxName = HiveService.incidentsBoxName;
  static const String outboxBoxName = HiveService.outboxBoxName;
  static const String metadataBoxName = HiveService.metadataBoxName;
  static const String _nextIncidentNumberKey = 'next_incident_number';

  final HiveInterface _hive;
  final int pageSize;
  final Uuid _uuid = const Uuid();
  Future<void>? _initFuture;

  Box<Incident> get _incidentsBox => _hive.box<Incident>(incidentsBoxName);
  Box<IncidentUpdate> get _outboxBox =>
      _hive.box<IncidentUpdate>(outboxBoxName);
  Box<dynamic> get _metadataBox => _hive.box<dynamic>(metadataBoxName);

  /// Returns the next display incident ID without consuming the counter.
  Future<String> generateNextIncidentId() async {
    await _ensureInitialized();
    return formatIncidentDisplayId(_peekNextIncidentNumber());
  }

  /// Reserves and returns the next incident number from metadata storage.
  Future<int> reserveNextIncidentNumber() async {
    await _ensureInitialized();
    final reserved = _peekNextIncidentNumber();
    await _metadataBox.put(_nextIncidentNumberKey, reserved + 1);
    return reserved;
  }

  /// Creates a new incident in local storage.
  @override
  Future<void> createIncident(Incident incident) async {
    await _ensureInitialized();
    var incidentToPersist = incident;
    if (incidentToPersist.id.trim().isEmpty) {
      // Internal IDs are immutable and backend-safe UUIDs.
      incidentToPersist = incidentToPersist.copyWith(id: _uuid.v4());
    }
    if (incidentToPersist.incidentNumber < 1) {
      // Protects against callers forgetting to reserve a display number.
      incidentToPersist = incidentToPersist.copyWith(
        incidentNumber: await reserveNextIncidentNumber(),
      );
    }

    if (_incidentsBox.containsKey(incidentToPersist.id)) {
      throw StateError(
        'Incident already exists for id: ${incidentToPersist.id}',
      );
    }
    await _incidentsBox.put(incidentToPersist.id, incidentToPersist);
    // Keep metadata counter ahead of imported/manual incident numbers.
    await _ensureCounterAtLeast(incidentToPersist.incidentNumber + 1);
  }

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
    if (!_hive.isBoxOpen(metadataBoxName)) {
      await _hive.openBox<dynamic>(metadataBoxName);
    }

    if (_incidentsBox.isEmpty) {
      // Seed incidents only once so local edits persist across app restarts.
      final seedData = buildMockIncidents(now: DateTime.now());
      await _incidentsBox.putAll({
        for (final incident in seedData) incident.id: incident,
      });
    }

    // Migrate legacy INC-keyed records to internal UUID keys.
    await _migrateLegacyIncidentIds();
    // Ensure the sequence counter is always valid after seed or migrations.
    await _synchronizeIncidentCounter();
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
      incident.displayId,
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

  /// Reads next number from metadata with a safe fallback for resilience.
  int _peekNextIncidentNumber() {
    final storedValue = _metadataBox.get(_nextIncidentNumberKey);
    if (storedValue is int && storedValue > 0) {
      return storedValue;
    }
    return _computeMaxIncidentNumber() + 1;
  }

  /// Finds the highest stored incident number from existing records.
  int _computeMaxIncidentNumber() {
    var maxNumber = 0;
    for (final incident in _incidentsBox.values) {
      if (incident.incidentNumber > maxNumber) {
        maxNumber = incident.incidentNumber;
      }
    }
    return maxNumber;
  }

  /// Keeps `nextIncidentNumber` aligned with stored incident data.
  Future<void> _synchronizeIncidentCounter() async {
    final minimumNext = _computeMaxIncidentNumber() + 1;
    await _ensureCounterAtLeast(minimumNext);
  }

  /// Advances counter only forward to avoid number reuse collisions.
  Future<void> _ensureCounterAtLeast(int minimumNext) async {
    final safeMinimum = minimumNext < 1 ? 1 : minimumNext;
    final current = _metadataBox.get(_nextIncidentNumberKey);
    if (current is int && current >= safeMinimum) {
      return;
    }
    await _metadataBox.put(_nextIncidentNumberKey, safeMinimum);
  }

  /// Migrates legacy incidents keyed by `INC-###` to UUID internal keys.
  Future<void> _migrateLegacyIncidentIds() async {
    final legacyPattern = RegExp(r'^INC-(\d+)$', caseSensitive: false);
    final legacyIncidents = _incidentsBox.values
        .where((incident) => legacyPattern.hasMatch(incident.id))
        .toList(growable: false);
    if (legacyIncidents.isEmpty) {
      return;
    }

    final existingIds = _incidentsBox.keys.whereType<String>().toSet();
    final remappedIds = <String, String>{};

    for (final legacyIncident in legacyIncidents) {
      // Guarantee uniqueness even if random UUID collision is extremely rare.
      var candidate = _uuid.v4();
      while (existingIds.contains(candidate) ||
          remappedIds.containsValue(candidate)) {
        candidate = _uuid.v4();
      }
      remappedIds[legacyIncident.id] = candidate;
      existingIds.add(candidate);
    }

    for (final legacyIncident in legacyIncidents) {
      await _incidentsBox.delete(legacyIncident.id);
    }
    await _incidentsBox.putAll({
      for (final legacyIncident in legacyIncidents)
        remappedIds[legacyIncident.id]!: legacyIncident.copyWith(
          id: remappedIds[legacyIncident.id],
        ),
    });

    // Keep outbox records pointing to valid incident internal IDs.
    for (final update in _outboxBox.values.toList(growable: false)) {
      final mappedIncidentId = remappedIds[update.incidentId];
      if (mappedIncidentId == null) {
        continue;
      }
      await _outboxBox.put(
        update.id,
        update.copyWith(incidentId: mappedIncidentId),
      );
    }
  }
}
