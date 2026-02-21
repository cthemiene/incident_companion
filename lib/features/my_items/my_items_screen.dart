import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/incident.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/severity_badge.dart';
import '../../shared/widgets/status_chip.dart';
import '../auth/auth_provider.dart';
import 'my_items_provider.dart';

/// Assigned-work view scoped to the currently signed-in user.
class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  String? _lastLoadedAssignee;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Reloads data whenever the authenticated user context changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final provider = context.read<MyItemsProvider>();
    final assignee = auth.currentUserEmail;
    if (assignee != _lastLoadedAssignee) {
      _lastLoadedAssignee = assignee;
      _searchController.text = provider.searchText;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<MyItemsProvider>().loadMyItems(assignedTo: assignee);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MyItemsProvider>();
    final assignee = context.watch<AuthProvider>().currentUserEmail;
    final hasFilters =
        provider.selectedSeverities.isNotEmpty ||
        provider.selectedStatuses.isNotEmpty ||
        provider.environment != null;

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
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
                      context.read<MyItemsProvider>().setSearch(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search my items',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                context.read<MyItemsProvider>().setSearch('');
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _openFilters(context, provider),
                  icon: Icon(
                    hasFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  ),
                  tooltip: 'Filters',
                ),
              ],
            ),
          ),
          if (provider.loading && provider.items.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody(context, provider, assignee)),
        ],
      ),
    );
  }

  /// Renders loading/error/empty/list states for My Items.
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
            : 'No incidents for $assignee match your current search/filters.',
        icon: Icons.assignment_outlined,
        actionLabel: 'Clear filters',
        onAction: () => provider.setFilters(clear: true),
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

  /// Opens top-down My Items filter panel (status/severity/environment).
  Future<void> _openFilters(
    BuildContext context,
    MyItemsProvider provider,
  ) async {
    final draftSeverities = provider.selectedSeverities.toSet();
    final draftStatuses = provider.selectedStatuses.toSet();
    var draftProdOnly = provider.environment == IncidentEnvironment.prod;

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'My Items Filters',
      barrierDismissible: true,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, __) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(22),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 680,
                        maxHeight: MediaQuery.of(context).size.height * 0.86,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text(
                                    'My Items Filters',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    icon: const Icon(Icons.close),
                                    tooltip: 'Close',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Status',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: IncidentStatus.values
                                    .map((status) {
                                      final selected = draftStatuses.contains(
                                        status,
                                      );
                                      return FilterChip(
                                        selected: selected,
                                        label: Text(_statusLabel(status)),
                                        onSelected: (value) {
                                          setSheetState(() {
                                            if (value) {
                                              draftStatuses.add(status);
                                            } else {
                                              draftStatuses.remove(status);
                                            }
                                          });
                                        },
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Severity',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: IncidentSeverity.values
                                    .map((severity) {
                                      final selected = draftSeverities.contains(
                                        severity,
                                      );
                                      return FilterChip(
                                        selected: selected,
                                        label: Text(
                                          severity.name.toUpperCase(),
                                        ),
                                        onSelected: (value) {
                                          setSheetState(() {
                                            if (value) {
                                              draftSeverities.add(severity);
                                            } else {
                                              draftSeverities.remove(severity);
                                            }
                                          });
                                        },
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                title: const Text('Production only'),
                                subtitle: const Text(
                                  'Turn off to include all environments',
                                ),
                                value: draftProdOnly,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) {
                                  setSheetState(() => draftProdOnly = value);
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      setSheetState(() {
                                        draftStatuses.clear();
                                        draftSeverities.clear();
                                        draftProdOnly = false;
                                      });
                                    },
                                    child: const Text('Reset'),
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      provider.setFilters(
                                        statuses: draftStatuses,
                                        severities: draftSeverities,
                                        environment: draftProdOnly
                                            ? IncidentEnvironment.prod
                                            : null,
                                      );
                                    },
                                    child: const Text('Apply'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.18),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Compact relative timestamp formatting for row metadata.
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

  /// Converts status enum values for filter chips.
  String _statusLabel(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.open:
        return 'Open';
      case IncidentStatus.inProgress:
        return 'In Progress';
      case IncidentStatus.resolved:
        return 'Resolved';
    }
  }
}
