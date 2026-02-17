import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/incident.dart';
import '../../data/repositories/mock_incident_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/severity_badge.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/update_incident_sheet.dart';

class IncidentDetailScreen extends StatefulWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  Incident? _incident;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIncident();
  }

  Future<void> _loadIncident() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final incident = await context
          .read<MockIncidentRepository>()
          .getIncidentById(widget.incidentId);
      if (!mounted) {
        return;
      }
      setState(() => _incident = incident);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Failed to load incident: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/incidents');
            }
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        title: const Text('Incident Details'),
      ),
      floatingActionButton: _incident == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openUpdateSheet(context, _incident!),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Update'),
            ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const LoadingSkeleton(itemCount: 4);
    }

    if (_error != null) {
      return EmptyState(
        title: 'Could not load incident',
        message: _error!,
        icon: Icons.error_outline,
        actionLabel: 'Retry',
        onAction: _loadIncident,
      );
    }

    final incident = _incident;
    if (incident == null) {
      return const EmptyState(
        title: 'Incident not found',
        message: 'This incident may have been deleted.',
        icon: Icons.search_off_outlined,
      );
    }

    final timeline = _buildTimeline(incident);
    final signalsCount = _fakeAppInsightsCount(incident.id);

    return RefreshIndicator(
      onRefresh: _loadIncident,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    incident.id,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    incident.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      SeverityBadge(severity: incident.severity),
                      const SizedBox(width: 8),
                      StatusChip(status: incident.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Key fields',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _KeyValueRow(label: 'Service', value: incident.service),
                  _KeyValueRow(
                    label: 'Environment',
                    value: incident.environment == IncidentEnvironment.prod
                        ? 'Production'
                        : 'Non-Prod',
                  ),
                  _KeyValueRow(
                    label: 'Created',
                    value: _formatDateTime(incident.createdAt),
                  ),
                  _KeyValueRow(
                    label: 'Updated',
                    value: _formatDateTime(incident.updatedAt),
                  ),
                  _KeyValueRow(
                    label: 'Assigned to',
                    value: incident.assignedTo ?? 'Unassigned',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Timeline',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...timeline.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(entry.message),
                      subtitle: Text(_formatDateTime(entry.time)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Signals',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'App Insights events (24h): $signalsCount',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is a placeholder metric for now.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEntry> _buildTimeline(Incident incident) {
    final entries = <_TimelineEntry>[
      _TimelineEntry(time: incident.createdAt, message: 'Incident created'),
      if (incident.assignedTo != null)
        _TimelineEntry(
          time: incident.createdAt.add(const Duration(minutes: 12)),
          message: 'Assigned to ${incident.assignedTo}',
        ),
      _TimelineEntry(
        time: incident.updatedAt,
        message: 'Status updated to ${_readableStatus(incident.status)}',
      ),
    ];
    entries.sort((a, b) => b.time.compareTo(a.time));
    return entries;
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year} $hour:$minute';
  }

  String _readableStatus(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.open:
        return 'Open';
      case IncidentStatus.inProgress:
        return 'In Progress';
      case IncidentStatus.resolved:
        return 'Resolved';
    }
  }

  int _fakeAppInsightsCount(String incidentId) {
    final seed = incidentId.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return 40 + (seed % 260);
  }

  Future<void> _openUpdateSheet(BuildContext context, Incident incident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UpdateIncidentSheet(
        incidentId: incident.id,
        onQueuedUpdate: (update) {
          if (!mounted) {
            return;
          }
          final current = _incident;
          if (current == null || update.newStatus == null) {
            return;
          }
          setState(
            () => _incident = current.copyWith(
              status: update.newStatus!,
              updatedAt: update.createdAt,
            ),
          );
        },
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({required this.time, required this.message});

  final DateTime time;
  final String message;
}
