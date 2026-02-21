import 'package:flutter/foundation.dart';

import '../../data/models/incident.dart';
import '../../data/repositories/incident_repository.dart';

class MyItemsProvider extends ChangeNotifier {
  MyItemsProvider(this._repository);

  final IncidentRepository _repository;

  List<Incident> _items = <Incident>[];
  bool _loading = false;
  String? _error;
  String? _assignee;

  List<Incident> get items => List<Incident>.unmodifiable(_items);
  bool get loading => _loading;
  String? get error => _error;
  String? get assignee => _assignee;
  bool get isEmpty => !_loading && _error == null && _items.isEmpty;

  Future<void> loadMyItems({required String? assignedTo}) async {
    _loading = true;
    _error = null;
    _assignee = assignedTo;
    notifyListeners();

    if (assignedTo == null || assignedTo.trim().isEmpty) {
      _items = <Incident>[];
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _items = await _repository.getIncidents(
        filters: <String, dynamic>{'assignedTo': assignedTo.trim()},
        page: 1,
      );
    } catch (error) {
      _error = 'Failed to load my items: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadMyItems(assignedTo: _assignee);
  }
}
