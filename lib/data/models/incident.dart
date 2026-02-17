import 'package:hive/hive.dart';

enum IncidentStatus { open, inProgress, resolved }

enum IncidentSeverity { s1, s2, s3, s4 }

enum IncidentEnvironment { prod, nonProd }

class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.severity,
    required this.service,
    required this.environment,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
  });

  final String id;
  final String title;
  final String description;
  final IncidentStatus status;
  final IncidentSeverity severity;
  final String service;
  final IncidentEnvironment environment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo;

  Incident copyWith({
    String? id,
    String? title,
    String? description,
    IncidentStatus? status,
    IncidentSeverity? severity,
    String? service,
    IncidentEnvironment? environment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedTo,
    bool clearAssignedTo = false,
  }) {
    return Incident(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      service: service ?? this.service,
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
      default:
        return IncidentSeverity.s4;
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

    return Incident(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      status: fields[3] as IncidentStatus,
      severity: fields[4] as IncidentSeverity,
      service: fields[5] as String,
      environment: fields[6] as IncidentEnvironment,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      assignedTo: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Incident obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.assignedTo);
  }
}

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
