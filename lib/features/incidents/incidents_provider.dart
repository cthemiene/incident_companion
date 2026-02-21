import 'package:flutter/foundation.dart';

import '../../data/models/incident.dart';
import '../../data/repositories/incident_repository.dart';

class IncidentsProvider extends ChangeNotifier {
  IncidentsProvider(
    this._repository, {
    this.meAssignee = 'engineer1@example.com',
  }) {
    _filters['status'] = _selectedTab;
  }

  final IncidentRepository _repository;
  final String meAssignee;

  List<Incident> _list = <Incident>[];
  bool _loading = false;
  String? _error;
  final Map<String, dynamic> _filters = <String, dynamic>{};
  String _searchText = '';
  IncidentStatus _selectedTab = IncidentStatus.open;
  Set<IncidentSeverity> _selectedSeverities = <IncidentSeverity>{};
  bool _assignedToMe = false;
  IncidentEnvironment? _environment;
  int _page = 1;

  List<Incident> get list => List<Incident>.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  Map<String, dynamic> get filters =>
      Map<String, dynamic>.unmodifiable(_filters);
  String get searchText => _searchText;
  IncidentStatus get selectedTab => _selectedTab;
  Set<IncidentSeverity> get selectedSeverities =>
      Set<IncidentSeverity>.unmodifiable(_selectedSeverities);
  bool get assignedToMe => _assignedToMe;
  IncidentEnvironment? get environment => _environment;
  bool get isEmpty => !_loading && _error == null && _list.isEmpty;

  Future<void> loadIncidents({int page = 1}) async {
    _loading = true;
    _error = null;
    _page = page < 1 ? 1 : page;
    notifyListeners();

    try {
      final hasSearchText = _searchText.trim().isNotEmpty;
      final effectiveFilters = _buildEffectiveFilters(
        ignoreStatusFilter: hasSearchText,
      );
      _list = await _repository.getIncidents(
        filters: effectiveFilters,
        search: hasSearchText ? _searchText.trim() : null,
        page: _page,
      );
    } catch (error) {
      _error = 'Failed to load incidents: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadIncidents(page: _page);
  }

  Future<void> setSearch(String value) async {
    _searchText = value;
    await loadIncidents(page: 1);
  }

  Future<void> setFilters({
    Set<IncidentSeverity>? severities,
    IncidentEnvironment? environment,
    bool? assignedToMe,
    bool clear = false,
  }) async {
    if (clear) {
      _filters.clear();
      _selectedSeverities = <IncidentSeverity>{};
      _assignedToMe = false;
      _environment = null;
    } else {
      if (severities != null) {
        _selectedSeverities = Set<IncidentSeverity>.from(severities);
      }
      if (assignedToMe != null) {
        _assignedToMe = assignedToMe;
      }
      _environment = environment;
    }

    _setOrRemoveFilter(
      'severity',
      _selectedSeverities.isEmpty
          ? null
          : _selectedSeverities.toList(growable: false),
    );
    _setOrRemoveFilter('environment', _environment);
    _setOrRemoveFilter('assignedTo', _assignedToMe ? meAssignee : null);

    _filters['status'] = _selectedTab;

    await loadIncidents(page: 1);
  }

  Future<void> setTab(IncidentStatus status) async {
    _selectedTab = status;
    _filters['status'] = status;
    await loadIncidents(page: 1);
  }

  void _setOrRemoveFilter(String key, dynamic value) {
    if (value == null) {
      _filters.remove(key);
      return;
    }
    if (value is String && value.isEmpty) {
      _filters.remove(key);
      return;
    }
    _filters[key] = value;
  }

  Map<String, dynamic>? _buildEffectiveFilters({
    required bool ignoreStatusFilter,
  }) {
    if (_filters.isEmpty) {
      return null;
    }

    final result = Map<String, dynamic>.from(_filters);
    if (ignoreStatusFilter) {
      result.remove('status');
    }

    return result.isEmpty ? null : result;
  }
}
