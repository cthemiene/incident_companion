import '../models/incident.dart';
import '../models/incident_update.dart';

/// Contract for incident read/update operations.
abstract class IncidentRepository {
  /// Persists a new incident record.
  Future<void> createIncident(Incident incident);

  /// Fetches paged incidents with optional filter/search criteria.
  Future<List<Incident>> getIncidents({
    Map<String, dynamic>? filters,
    String? search,
    int page = 1,
  });

  /// Fetches a single incident by id.
  Future<Incident> getIncidentById(String id);

  /// Queues an incident update for later sync.
  Future<void> queueUpdate(IncidentUpdate update);

  /// Returns queued updates (outbox style list).
  Future<List<IncidentUpdate>> getOutbox();

  /// Removes an update from the queue.
  Future<void> deleteOutboxItem(String updateId);
}
