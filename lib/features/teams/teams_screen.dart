import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/mock/mock_org_teams.dart';
import '../../shared/utils/user_role.dart';
import '../auth/auth_provider.dart';

/// Team management page with role-based visibility and edit permissions.
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUserRole;
    final currentTeamId = auth.currentTeamId;
    final currentOrganizationId = auth.currentOrganizationId;
    final visibleTeams = _visibleTeamsForRole(
      role: role,
      currentTeamId: currentTeamId,
    );
    final teamsByOrganization = _groupTeamsByOrganization(visibleTeams);

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
        title: const Text('Teams'),
      ),
      body: Column(
        children: <Widget>[
          // Explains role-specific capabilities to set expectations up front.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _RoleSummaryBanner(text: _roleSummary(role)),
          ),
          Expanded(
            child: visibleTeams.isEmpty
                ? const Center(
                    child: Text('No teams available for the current user.'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: teamsByOrganization.entries
                        .map((entry) {
                          final organizationId = entry.key;
                          final teams = entry.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 8,
                                ),
                                child: Text(
                                  mockOrganizationLabel(organizationId),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              ...teams.map(
                                (team) => _TeamCard(
                                  team: team,
                                  isCurrentTeam: team.id == currentTeamId,
                                  canEdit: _canEditTeam(
                                    role: role,
                                    currentTeamId: currentTeamId,
                                    currentOrganizationId:
                                        currentOrganizationId,
                                    team: team,
                                  ),
                                  onEdit: () => _openTeamEditor(
                                    team: team,
                                    role: role,
                                    currentTeamId: currentTeamId,
                                  ),
                                ),
                              ),
                            ],
                          );
                        })
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }

  /// Returns teams visible to current role based on requested access policy.
  List<MockTeamDefinition> _visibleTeamsForRole({
    required UserRole role,
    required String? currentTeamId,
  }) {
    final allTeams = List<MockTeamDefinition>.from(mockTeamDefinitions);
    allTeams.sort((a, b) {
      final orgCompare = a.organizationId.compareTo(b.organizationId);
      if (orgCompare != 0) {
        return orgCompare;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    switch (role) {
      case UserRole.admin:
      case UserRole.manager:
        // Managers can view all teams but only edit their current team.
        return allTeams;
      case UserRole.member:
        // Members can only view their own current team.
        return allTeams.where((team) => team.id == currentTeamId).toList();
    }
  }

  /// Groups teams by organization so the page reads like a small org directory.
  Map<String, List<MockTeamDefinition>> _groupTeamsByOrganization(
    List<MockTeamDefinition> teams,
  ) {
    final result = <String, List<MockTeamDefinition>>{};
    for (final team in teams) {
      result.putIfAbsent(team.organizationId, () => <MockTeamDefinition>[]);
      result[team.organizationId]!.add(team);
    }
    return result;
  }

  /// Determines if the current user can edit this team entry.
  bool _canEditTeam({
    required UserRole role,
    required String? currentTeamId,
    required String? currentOrganizationId,
    required MockTeamDefinition team,
  }) {
    switch (role) {
      case UserRole.admin:
        return true;
      case UserRole.manager:
        // Managers may only edit their own current team in their organization.
        return team.id == currentTeamId &&
            team.organizationId == currentOrganizationId;
      case UserRole.member:
        return false;
    }
  }

  /// Launches editor and refreshes list after a successful team update.
  Future<void> _openTeamEditor({
    required MockTeamDefinition team,
    required UserRole role,
    required String? currentTeamId,
  }) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _TeamEditorDialog(
        team: team,
        // Editor enablement is based on current role + target team.
        isEditable:
            role == UserRole.admin ||
            (role == UserRole.manager && team.id == currentTeamId),
      ),
    );
    if (updated != true || !mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Team updated')));
  }

  /// Human-readable summary of role capabilities on this page.
  String _roleSummary(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin: view and edit all teams.';
      case UserRole.manager:
        return 'Manager: edit current team and view other teams.';
      case UserRole.member:
        return 'Member: view current team only.';
    }
  }
}

/// Lightweight card for a single team row.
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.isCurrentTeam,
    required this.canEdit,
    required this.onEdit,
  });

  final MockTeamDefinition team;
  final bool isCurrentTeam;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.groups_outlined),
        title: Row(
          children: <Widget>[
            Expanded(child: Text(team.displayName)),
            if (isCurrentTeam)
              const Chip(
                label: Text('Current'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Text('ID: ${team.id}\n${team.description}'),
        isThreeLine: true,
        trailing: canEdit
            ? IconButton(
                // Edit action is hidden for rows where role has no edit rights.
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit team',
              )
            : null,
      ),
    );
  }
}

/// Simple informational banner for role capability hints.
class _RoleSummaryBanner extends StatelessWidget {
  const _RoleSummaryBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// Team editor used by admins and manager-current-team workflow.
class _TeamEditorDialog extends StatefulWidget {
  const _TeamEditorDialog({required this.team, required this.isEditable});

  final MockTeamDefinition team;
  final bool isEditable;

  @override
  State<_TeamEditorDialog> createState() => _TeamEditorDialogState();
}

class _TeamEditorDialogState extends State<_TeamEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Starts form values from the selected team definition.
    _nameController = TextEditingController(text: widget.team.displayName);
    _descriptionController = TextEditingController(
      text: widget.team.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Team'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              initialValue: widget.team.id,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Team ID'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: mockOrganizationLabel(widget.team.organizationId),
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Organization'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              readOnly: !widget.isEditable,
              decoration: const InputDecoration(labelText: 'Team Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              readOnly: !widget.isEditable,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        if (widget.isEditable)
          FilledButton(
            // Writes updated team metadata to centralized mock directory.
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
      ],
    );
  }

  /// Persists team updates and reports success to caller.
  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = updateMockTeamDefinition(
      teamId: widget.team.id,
      displayName: _nameController.text,
      description: _descriptionController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team name cannot be empty')),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }
}
