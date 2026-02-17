import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/incident.dart';
import '../../data/models/incident_update.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_skeleton.dart';
import 'outbox_provider.dart';

class OutboxScreen extends StatefulWidget {
  const OutboxScreen({super.key});

  @override
  State<OutboxScreen> createState() => _OutboxScreenState();
}

class _OutboxScreenState extends State<OutboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<OutboxProvider>().loadOutbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OutboxProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outbox'),
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
        actions: <Widget>[
          TextButton.icon(
            onPressed: provider.loading
                ? null
                : () => context.read<OutboxProvider>().simulateSync(),
            icon: const Icon(Icons.sync),
            label: const Text('Simulate Sync'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, OutboxProvider provider) {
    if (provider.loading && provider.list.isEmpty) {
      return const LoadingSkeleton(itemCount: 4);
    }

    if (provider.error != null && provider.list.isEmpty) {
      return EmptyState(
        title: 'Could not load outbox',
        message: provider.error!,
        icon: Icons.error_outline,
        actionLabel: 'Retry',
        onAction: provider.loadOutbox,
      );
    }

    if (provider.list.isEmpty) {
      return const EmptyState(
        title: 'Outbox is empty',
        message: 'Queued incident updates will show here.',
        icon: Icons.outbox_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadOutbox,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: provider.list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final update = provider.list[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              context.push('/incidents/${update.incidentId}'),
                          child: Text(
                            update.incidentId,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      _SyncStateChip(state: update.syncState),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, HH:mm').format(update.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusChangeLabel(update),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    update.comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  if (update.lastError != null && update.lastError!.isNotEmpty)
                    Text(
                      update.lastError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      if (update.syncState == SyncState.failed)
                        TextButton.icon(
                          onPressed: provider.loading
                              ? null
                              : () => provider.retry(update.id),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: provider.loading
                            ? null
                            : () => provider.delete(update.id),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _statusChangeLabel(IncidentUpdate update) {
    if (update.newStatus == null) {
      return 'Status change: none';
    }
    switch (update.newStatus!) {
      case IncidentStatus.open:
        return 'Status change: Open';
      case IncidentStatus.inProgress:
        return 'Status change: In Progress';
      case IncidentStatus.resolved:
        return 'Status change: Resolved';
    }
  }
}

class _SyncStateChip extends StatelessWidget {
  const _SyncStateChip({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bgColor, fgColor) = switch (state) {
      SyncState.pending => (
        'Pending',
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      SyncState.failed => (
        'Failed',
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      SyncState.synced => (
        'Synced',
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
