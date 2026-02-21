import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/severity_badge.dart';
import '../../shared/widgets/status_chip.dart';
import '../auth/auth_provider.dart';
import 'my_items_provider.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  String? _lastLoadedAssignee;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final assignee = context.read<AuthProvider>().currentUserEmail;
    if (assignee == _lastLoadedAssignee) {
      return;
    }
    _lastLoadedAssignee = assignee;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<MyItemsProvider>().loadMyItems(assignedTo: assignee);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MyItemsProvider>();
    final assignee = context.watch<AuthProvider>().currentUserEmail;

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
        title: const Text('My Items'),
      ),
      body: _buildBody(context, provider, assignee),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MyItemsProvider provider,
    String? assignee,
  ) {
    if (provider.loading && provider.items.isEmpty) {
      return const LoadingSkeleton(itemCount: 4);
    }

    if (provider.error != null && provider.items.isEmpty) {
      return EmptyState(
        title: 'Could not load my items',
        message: provider.error!,
        icon: Icons.error_outline,
        actionLabel: 'Retry',
        onAction: provider.refresh,
      );
    }

    if (provider.items.isEmpty) {
      return EmptyState(
        title: 'No assigned items',
        message: assignee == null
            ? 'Sign in to view assigned incidents.'
            : 'No incidents are currently assigned to $assignee.',
        icon: Icons.assignment_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: provider.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final incident = provider.items[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/incidents/${incident.id}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${incident.id}  ${incident.title}',
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            incident.service,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Updated ${_timeAgo(incident.updatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        SeverityBadge(severity: incident.severity),
                        const SizedBox(height: 8),
                        StatusChip(status: incident.status),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}
