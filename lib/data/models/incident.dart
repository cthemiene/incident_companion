import 'package:hive/hive.dart';

import '../mock/mock_scope_data.dart';
import '../mock/mock_users.dart';

/// Lifecycle state for an incident ticket.
enum IncidentStatus { open, inProgress, resolved }

/// Business severity scale where S5 is the lowest default severity.
enum IncidentSeverity { s1, s2, s3, s4, s5 }

/// Deployment environment impacted by the incident.
enum IncidentEnvironment { prod, nonProd }

/// Primary incident entity stored in Hive and used across the UI.
class Incident {
  const Incident({
    required this.id,
    required this.incidentNumber,
    required this.title,
    required this.description,
    required this.status,
    this.severity = IncidentSeverity.s5,
    required this.service,
    required this.organizationId,
    required this.teamId,
    required this.environment,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
  });

  /// Internal immutable identifier (UUID for newly created incidents).
  final String id;

  /// Monotonic ticket number used to render customer-facing `INC-` IDs.
  final int incidentNumber;
  final String title;
  final String description;
  final IncidentStatus status;
  final IncidentSeverity severity;
  final String service;
  final String organizationId;
  final String teamId;
  final IncidentEnvironment environment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo;

  /// Public-facing incident ticket identifier (for example, `INC-000123`).
  String get displayId => formatIncidentDisplayId(incidentNumber);

  /// Returns a modified copy while preserving unchanged fields.
  Incident copyWith({
    String? id,
    int? incidentNumber,
    String? title,
    String? description,
    IncidentStatus? status,
    IncidentSeverity? severity,
    String? service,
    String? organizationId,
    String? teamId,
    IncidentEnvironment? environment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedTo,
    bool clearAssignedTo = false,
  }) {
    return Incident(
      id: id ?? this.id,
      incidentNumber: incidentNumber ?? this.incidentNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      service: service ?? this.service,
      organizationId: organizationId ?? this.organizationId,
      teamId: teamId ?? this.teamId,
      environment: environment ?? this.environment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
    );
  }
}

class IncidentStatusAdapter extends TypeAdapter<IncidentStatus> {
  @override
  final int typeId = 0;

  @override
  IncidentStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncidentStatus.open;
      case 1:
        return IncidentStatus.inProgress;
      case 2:
        return IncidentStatus.resolved;
      default:
        return IncidentStatus.open;
    }
  }

  @override
  void write(BinaryWriter writer, IncidentStatus obj) {
    switch (obj) {
      case IncidentStatus.open:
        writer.writeByte(0);
      case IncidentStatus.inProgress:
        writer.writeByte(1);
      case IncidentStatus.resolved:
        writer.writeByte(2);
    }
  }
}

class IncidentSeverityAdapter extends TypeAdapter<IncidentSeverity> {
  @override
  final int typeId = 1;

  @override
  IncidentSeverity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncidentSeverity.s1;
      case 1:
        return IncidentSeverity.s2;
      case 2:
        return IncidentSeverity.s3;
      case 3:
        return IncidentSeverity.s4;
      case 4:
        return IncidentSeverity.s5;
      default:
        return IncidentSeverity.s5;
    }
  }

  @override
  void write(BinaryWriter writer, IncidentSeverity obj) {
    switch (obj) {
      case IncidentSeverity.s1:
        writer.writeByte(0);
      case IncidentSeverity.s2:
        writer.writeByte(1);
      case IncidentSeverity.s3:
        writer.writeByte(2);
      case IncidentSeverity.s4:
        writer.writeByte(3);
      case IncidentSeverity.s5:
        writer.writeByte(4);
    }
  }
}

class IncidentEnvironmentAdapter extends TypeAdapter<IncidentEnvironment> {
  @override
  final int typeId = 2;

  @override
  IncidentEnvironment read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IncidentEnvironment.prod;
      case 1:
        return IncidentEnvironment.nonProd;
      default:
        return IncidentEnvironment.nonProd;
    }
  }

  @override
  void write(BinaryWriter writer, IncidentEnvironment obj) {
    switch (obj) {
      case IncidentEnvironment.prod:
        writer.writeByte(0);
      case IncidentEnvironment.nonProd:
        writer.writeByte(1);
    }
  }
}

/// Hive adapter for the `Incident` object schema.
class IncidentAdapter extends TypeAdapter<Incident> {
  @override
  final int typeId = 3;

  @override
  Incident read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{};
    for (var index = 0; index < fieldCount; index++) {
      fields[reader.readByte()] = reader.read();
    }

    // Legacy records stored `id` as `INC-###`; newer records persist number
    // separately for scalable display IDs.
    final legacyOrInternalId = fields[0] as String;
    final rawIncidentNumber = fields[10];
    final persistedIncidentNumber = rawIncidentNumber is int
        ? rawIncidentNumber
        : int.tryParse('$rawIncidentNumber');
    final assignedProfile = findMockUserProfileByEmail(fields[9] as String?);
    final rawOrganizationId = fields[11] as String?;
    final rawTeamId = fields[12] as String?;
    return Incident(
      id: legacyOrInternalId,
      incidentNumber:
          persistedIncidentNumber ??
          _parseIncidentNumberFromLegacyId(legacyOrInternalId),
      title: fields[1] as String,
      description: fields[2] as String,
      status: fields[3] as IncidentStatus,
      severity: fields[4] as IncidentSeverity,
      service: fields[5] as String,
      organizationId:
          rawOrganizationId ??
          assignedProfile?.organizationId ??
          defaultMockOrganizationId,
      teamId: rawTeamId ?? assignedProfile?.teamId ?? defaultMockTeamId,
      environment: fields[6] as IncidentEnvironment,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      assignedTo: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Incident obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.severity)
      ..writeByte(5)
      ..write(obj.service)
      ..writeByte(6)
      ..write(obj.environment)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.assignedTo)
      ..writeByte(10)
      ..write(obj.incidentNumber)
      ..writeByte(11)
      ..write(obj.organizationId)
      ..writeByte(12)
      ..write(obj.teamId);
  }
}

/// Formats numeric incident sequence values into user-facing `INC-` IDs.
String formatIncidentDisplayId(int incidentNumber, {int minDigits = 6}) {
  final normalizedNumber = incidentNumber < 1 ? 1 : incidentNumber;
  final normalizedWidth = minDigits < 1 ? 1 : minDigits;
  return 'INC-${normalizedNumber.toString().padLeft(normalizedWidth, '0')}';
}

/// Extracts sequence number from legacy IDs that were stored as `INC-###`.
int _parseIncidentNumberFromLegacyId(String value) {
  final match = RegExp(r'^INC-(\d+)$', caseSensitive: false).firstMatch(value);
  final parsed = int.tryParse(match?.group(1) ?? '');
  return (parsed == null || parsed < 1) ? 1 : parsed;
}

/// Registers all incident-related adapters once at startup.
void registerIncidentAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(IncidentStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(IncidentSeverityAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(IncidentEnvironmentAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(IncidentAdapter());
  }
}
