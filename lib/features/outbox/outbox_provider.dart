import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/models/incident_update.dart';
import '../../data/repositories/incident_repository.dart';

class OutboxProvider extends ChangeNotifier {
  OutboxProvider(this._repository, {Random? random})
    : _random = random ?? Random();

  final IncidentRepository _repository;
  final Random _random;

  List<IncidentUpdate> _list = <IncidentUpdate>[];
  bool _loading = false;
  String? _error;

  List<IncidentUpdate> get list => List<IncidentUpdate>.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  bool get isEmpty => !_loading && _error == null && _list.isEmpty;

  Future<void> loadOutbox() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _list = await _repository.getOutbox();
    } catch (error) {
      _error = 'Failed to load outbox: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> retry(String updateId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final matchIndex = _list.indexWhere((item) => item.id == updateId);
      if (matchIndex == -1) {
        throw StateError('Outbox item not found: $updateId');
      }
      final existing = _list[matchIndex];

      final retried = existing.copyWith(
        syncState: SyncState.pending,
        clearLastError: true,
      );
      await _repository.queueUpdate(retried);
      _list = await _repository.getOutbox();
    } catch (error) {
      _error = 'Failed to retry outbox item: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> delete(String updateId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.deleteOutboxItem(updateId);
      _list = await _repository.getOutbox();
    } catch (error) {
      _error = 'Failed to delete outbox item: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> simulateSync() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final currentOutbox = await _repository.getOutbox();

      for (final item in currentOutbox) {
        if (item.syncState != SyncState.pending) {
          continue;
        }

        final isSynced = _random.nextInt(100) < 65;
        final updated = item.copyWith(
          syncState: isSynced ? SyncState.synced : SyncState.failed,
          clearLastError: isSynced,
          lastError: isSynced ? null : 'Mock sync failure: network timeout.',
        );

        await _repository.queueUpdate(updated);
      }

      _list = await _repository.getOutbox();
    } catch (error) {
      _error = 'Failed to simulate sync: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
