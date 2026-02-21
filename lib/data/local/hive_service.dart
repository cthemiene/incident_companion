import 'package:hive_flutter/hive_flutter.dart';

import '../models/incident.dart';
import '../models/incident_update.dart';

/// Responsible for one-time Hive setup and typed box accessors.
class HiveService {
  HiveService._();

  static const String incidentsBoxName = 'incidents_box';
  static const String outboxBoxName = 'outbox_box';
  static const String authBoxName = 'auth_box';

  /// Initializes Hive, registers adapters, and opens app boxes.
  static Future<void> initialize() async {
    await Hive.initFlutter();

    registerIncidentAdapters();
    registerIncidentUpdateAdapters();

    if (!Hive.isBoxOpen(incidentsBoxName)) {
      await Hive.openBox<Incident>(incidentsBoxName);
    }
    if (!Hive.isBoxOpen(outboxBoxName)) {
      await Hive.openBox<IncidentUpdate>(outboxBoxName);
    }
    if (!Hive.isBoxOpen(authBoxName)) {
      await Hive.openBox<String>(authBoxName);
    }
  }

  /// Box storing incidents used by list/detail/my-items flows.
  static Box<Incident> get incidentsBox => Hive.box<Incident>(incidentsBoxName);

  /// Box storing queued updates used by offline/sync simulations.
  static Box<IncidentUpdate> get outboxBox =>
      Hive.box<IncidentUpdate>(outboxBoxName);

  /// Box storing mock auth session data.
  static Box<String> get authBox => Hive.box<String>(authBoxName);
}
