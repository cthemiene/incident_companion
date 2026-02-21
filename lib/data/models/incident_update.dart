import 'package:hive/hive.dart';

import 'incident.dart';

/// Visibility scope for update notes.
enum IncidentVisibility { workNotes, customerVisible }

/// Local sync lifecycle for queued updates.
enum SyncState { pending, failed, synced }

/// Offline-first update payload queued before backend sync.
class IncidentUpdate {
  const IncidentUpdate({
    required this.id,
    required this.incidentId,
    this.newStatus,
    this.assignedTo,
    required this.comment,
    required this.visibility,
    required this.createdAt,
    required this.syncState,
    this.lastError,
  });

  final String id;
  final String incidentId;
  final IncidentStatus? newStatus;
  final String? assignedTo;
  final String comment;
  final IncidentVisibility visibility;
  final DateTime createdAt;
  final SyncState syncState;
  final String? lastError;

  /// Returns a modified copy while preserving unchanged fields.
  IncidentUpdate copyWith({
    String? id,
    String? incidentId,
    IncidentStatus? newStatus,
    bool clearNewStatus = false,
    String? assignedTo,
    bool clearAssignedTo = false,
    String? comment,
    IncidentVisibility? visibility,
    DateTime? createdAt,
    SyncState? syncState,
    String? lastError,
    bool clearLastError = false,
  }) {
    return IncidentUpdate(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      newStatus: clearNewStatus ? null : (newStatus ?? this.newStatus),
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      comment: comment ?? this.comment,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      syncState: syncState ?? this.syncState,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class IncidentVisibilityAdapter extends TypeAdapter<IncidentVisibility> {
  @override
  final int typeId = 4;

  @override
  IncidentVisibility read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncidentVisibility.workNotes;
      case 1:
        return IncidentVisibility.customerVisible;
      default:
        return IncidentVisibility.workNotes;
    }
  }

  @override
  void write(BinaryWriter writer, IncidentVisibility obj) {
    switch (obj) {
      case IncidentVisibility.workNotes:
        writer.writeByte(0);
      case IncidentVisibility.customerVisible:
        writer.writeByte(1);
    }
  }
}

class SyncStateAdapter extends TypeAdapter<SyncState> {
  @override
  final int typeId = 5;

  @override
  SyncState read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncState.pending;
      case 1:
        return SyncState.failed;
      case 2:
        return SyncState.synced;
      default:
        return SyncState.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SyncState obj) {
    switch (obj) {
      case SyncState.pending:
        writer.writeByte(0);
      case SyncState.failed:
        writer.writeByte(1);
      case SyncState.synced:
        writer.writeByte(2);
    }
  }
}

/// Hive adapter for persisted incident update queue items.
class IncidentUpdateAdapter extends TypeAdapter<IncidentUpdate> {
  @override
  final int typeId = 6;

  @override
  IncidentUpdate read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }

    return IncidentUpdate(
      id: fields[0] as String,
      incidentId: fields[1] as String,
      newStatus: fields[2] as IncidentStatus?,
      comment: fields[3] as String,
      visibility: fields[4] as IncidentVisibility,
      createdAt: fields[5] as DateTime,
      syncState: fields[6] as SyncState,
      lastError: fields[7] as String?,
      assignedTo: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, IncidentUpdate obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.incidentId)
      ..writeByte(2)
      ..write(obj.newStatus)
      ..writeByte(3)
      ..write(obj.comment)
      ..writeByte(4)
      ..write(obj.visibility)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.syncState)
      ..writeByte(7)
      ..write(obj.lastError)
      ..writeByte(8)
      ..write(obj.assignedTo);
  }
}

/// Registers all incident-update-related adapters once at startup.
void registerIncidentUpdateAdapters() {
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(IncidentVisibilityAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(SyncStateAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(IncidentUpdateAdapter());
  }
}
