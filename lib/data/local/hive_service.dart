import 'package:hive_flutter/hive_flutter.dart';

import '../models/incident.dart';
import '../models/incident_update.dart';

class HiveService {
  HiveService._();

  static const String incidentsBoxName = 'incidents_box';
  static const String outboxBoxName = 'outbox_box';
  static const String authBoxName = 'auth_box';

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

  static Box<Incident> get incidentsBox => Hive.box<Incident>(incidentsBoxName);

  static Box<IncidentUpdate> get outboxBox =>
      Hive.box<IncidentUpdate>(outboxBoxName);

  static Box<String> get authBox => Hive.box<String>(authBoxName);
}
