import 'package:flutter/foundation.dart';

import '../../data/models/incident.dart';
import '../../data/repositories/incident_repository.dart';

/// State manager for the current user's assigned incidents only.
class MyItemsProvider extends ChangeNotifier {
  MyItemsProvider(this._repository);

  final IncidentRepository _repository;

  List<Incident> _items = <Incident>[];
  bool _loading = false;
  String? _error;
  String? _assignee;
  String _searchText = '';
  Set<IncidentSeverity> _selectedSeverities = <IncidentSeverity>{};
  Set<IncidentStatus> _selectedStatuses = <IncidentStatus>{};
  IncidentEnvironment? _environment;

  List<Incident> get items => List<Incident>.unmodifiable(_items);
  bool get loading => _loading;
  String? get error => _error;
  String? get assignee => _assignee;
  String get searchText => _searchText;
  Set<IncidentSeverity> get selectedSeverities =>
      Set<IncidentSeverity>.unmodifiable(_selectedSeverities);
  Set<IncidentStatus> get selectedStatuses =>
      Set<IncidentStatus>.unmodifiable(_selectedStatuses);
  IncidentEnvironment? get environment => _environment;
  bool get isEmpty => !_loading && _error == null && _items.isEmpty;

  /// Loads assigned incidents and applies My Items search/filter settings.
  Future<void> loadMyItems({required String? assignedTo}) async {
    _loading = true;
    _error = null;
    _assignee = assignedTo?.trim();
    notifyListeners();

    if (_assignee == null || _assignee!.isEmpty) {
      _items = <Incident>[];
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final filters = <String, dynamic>{'assignedTo': _assignee!};
      if (_selectedSeverities.isNotEmpty) {
        filters['severity'] = _selectedSeverities.toList(growable: false);
      }
      if (_selectedStatuses.isNotEmpty) {
        filters['status'] = _selectedStatuses.toList(growable: false);
      }
      if (_environment != null) {
        filters['environment'] = _environment;
      }

      _items = await _repository.getIncidents(
        filters: filters,
        search: _searchText.trim().isEmpty ? null : _searchText.trim(),
        page: 1,
      );
    } catch (error) {
      _error = 'Failed to load my items: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Re-runs the active My Items query.
  Future<void> refresh() async {
    await loadMyItems(assignedTo: _assignee);
  }

  /// Updates search text and reloads My Items.
  Future<void> setSearch(String value) async {
    _searchText = value;
    await loadMyItems(assignedTo: _assignee);
  }

  /// Updates My Items-only filters and reloads list.
  Future<void> setFilters({
    Set<IncidentSeverity>? severities,
    Set<IncidentStatus>? statuses,
    IncidentEnvironment? environment,
    bool clear = false,
  }) async {
    if (clear) {
      _selectedSeverities = <IncidentSeverity>{};
      _selectedStatuses = <IncidentStatus>{};
      _environment = null;
    } else {
      if (severities != null) {
        _selectedSeverities = Set<IncidentSeverity>.from(severities);
      }
      if (statuses != null) {
        _selectedStatuses = Set<IncidentStatus>.from(statuses);
      }
      _environment = environment;
    }
    await loadMyItems(assignedTo: _assignee);
  }
}
