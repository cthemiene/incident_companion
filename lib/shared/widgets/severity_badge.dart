import 'package:flutter/material.dart';

import '../../data/models/incident.dart';

/// Color-coded severity label used on incident cards.
class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final IncidentSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, fgColor) = switch (severity) {
      IncidentSeverity.s1 => ('S1', const Color(0xFFB42318), Colors.white),
      IncidentSeverity.s2 => ('S2', const Color(0xFFDD6B20), Colors.white),
      IncidentSeverity.s3 => ('S3', const Color(0xFF1C6BFF), Colors.white),
      IncidentSeverity.s4 => (
        'S4',
        const Color(0xFFE8EDF5),
        const Color(0xFF334155),
      ),
      IncidentSeverity.s5 => (
        'S5',
        const Color(0xFFF8FAFC),
        const Color(0xFF64748B),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
