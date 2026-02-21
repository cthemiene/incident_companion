import 'package:flutter/material.dart';

import '../../data/models/incident.dart';

/// Color-coded status chip with dot indicator.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, fgColor) = switch (status) {
      IncidentStatus.open => (
        'Open',
        const Color(0xFFFEE4E2),
        const Color(0xFF7A271A),
      ),
      IncidentStatus.inProgress => (
        'In Progress',
        const Color(0xFFE0ECFF),
        const Color(0xFF113A8F),
      ),
      IncidentStatus.resolved => (
        'Resolved',
        const Color(0xFFD9F8EC),
        const Color(0xFF085D3A),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fgColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
