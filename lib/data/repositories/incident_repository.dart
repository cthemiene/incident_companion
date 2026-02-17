import '../models/incident.dart';
import '../models/incident_update.dart';

abstract class IncidentRepository {
  Future<List<Incident>> getIncidents({
    Map<String, dynamic>? filters,
    String? search,
    int page = 1,
  });

  Future<Incident> getIncidentById(String id);

  Future<void> queueUpdate(IncidentUpdate update);

  Future<List<IncidentUpdate>> getOutbox();

  Future<void> deleteOutboxItem(String updateId);
}
