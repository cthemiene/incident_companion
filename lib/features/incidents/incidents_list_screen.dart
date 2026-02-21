import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/incident.dart';
import '../auth/auth_provider.dart';
import 'incidents_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_skeleton.dart';
import '../../shared/widgets/severity_badge.dart';
import '../../shared/widgets/status_chip.dart';

class IncidentsListScreen extends StatefulWidget {
  const IncidentsListScreen({super.key});

  @override
  State<IncidentsListScreen> createState() => _IncidentsListScreenState();
}

class _IncidentsListScreenState extends State<IncidentsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<IncidentsProvider>();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _statusToIndex(provider.selectedTab),
    );
    _searchController = TextEditingController(text: provider.searchText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<IncidentsProvider>().loadIncidents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IncidentsProvider>();
    final hasFilters =
        provider.selectedSeverities.isNotEmpty ||
        provider.assignedToMe ||
        provider.environment != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidents'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/my-items'),
            tooltip: 'My Items',
            icon: const Icon(Icons.assignment_ind_outlined),
          ),
          PopupMenuButton<_AppMenuAction>(
            onSelected: (action) async {
              if (action == _AppMenuAction.signOut) {
                await context.read<AuthProvider>().signOut();
                if (!context.mounted) {
                  return;
                }
                context.go('/login');
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<_AppMenuAction>>[
              PopupMenuItem<_AppMenuAction>(
                value: _AppMenuAction.signOut,
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) =>
              context.read<IncidentsProvider>().setTab(_indexToStatus(index)),
          tabs: const <Tab>[
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
          ],
        ),
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
                      context.read<IncidentsProvider>().setSearch(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search incidents',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                context.read<IncidentsProvider>().setSearch('');
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
          if (provider.loading && provider.list.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildContent(context, provider)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, IncidentsProvider provider) {
    if (provider.loading && provider.list.isEmpty) {
      return const LoadingSkeleton();
    }

    if (provider.error != null && provider.list.isEmpty) {
      return EmptyState(
        title: 'Could not load incidents',
        message: provider.error!,
        icon: Icons.error_outline,
        actionLabel: 'Retry',
        onAction: provider.refresh,
      );
    }

    if (provider.list.isEmpty) {
      return EmptyState(
        title: 'No incidents found',
        message: 'Try clearing filters or changing the search text.',
        icon: Icons.search_off_outlined,
        actionLabel: 'Reset filters',
        onAction: () => provider.setFilters(clear: true),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: provider.list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final incident = provider.list[index];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
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

  Future<void> _openFilters(
    BuildContext context,
    IncidentsProvider provider,
  ) async {
    final draftSeverities = provider.selectedSeverities.toSet();
    var draftAssignedToMe = provider.assignedToMe;
    var draftProdOnly = provider.environment == IncidentEnvironment.prod;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                            final selected = draftSeverities.contains(severity);
                            return FilterChip(
                              selected: selected,
                              label: Text(severity.name.toUpperCase()),
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
                      title: const Text('Assigned to me'),
                      value: draftAssignedToMe,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setSheetState(() => draftAssignedToMe = value);
                      },
                    ),
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
                              draftSeverities.clear();
                              draftAssignedToMe = false;
                              draftProdOnly = false;
                            });
                          },
                          child: const Text('Reset'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            provider.setFilters(
                              severities: draftSeverities,
                              assignedToMe: draftAssignedToMe,
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
            );
          },
        );
      },
    );
  }

  int _statusToIndex(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.open:
        return 0;
      case IncidentStatus.inProgress:
        return 1;
      case IncidentStatus.resolved:
        return 2;
    }
  }

  IncidentStatus _indexToStatus(int index) {
    switch (index) {
      case 0:
        return IncidentStatus.open;
      case 1:
        return IncidentStatus.inProgress;
      case 2:
      default:
        return IncidentStatus.resolved;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return DateFormat('MMM d, HH:mm').format(timestamp);
  }
}

enum _AppMenuAction { signOut }
