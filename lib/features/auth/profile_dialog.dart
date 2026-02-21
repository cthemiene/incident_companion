import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock/mock_users.dart';
import '../../shared/utils/user_role.dart';
import 'auth_provider.dart';

/// Large profile dialog that shows and updates the active user's metadata.
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({super.key});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _organizationController;
  late final TextEditingController _teamController;
  late UserRole _draftRole;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    // Seeds form state from the current in-memory authenticated profile.
    _emailController = TextEditingController(text: auth.currentUserEmail ?? '');
    _organizationController = TextEditingController(
      text: auth.currentOrganizationId ?? '',
    );
    _teamController = TextEditingController(text: auth.currentTeamId ?? '');
    _draftRole = auth.currentUserRole;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _organizationController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUserRole;
    final canEditAll = role == UserRole.admin;
    final orgMembers = getOrganizationMembers(
      organizationId: auth.currentOrganizationId,
      excludeEmail: auth.currentUserEmail,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            children: <Widget>[
              // Header emphasizes who is signed in and which role controls edits.
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    child: Text(_avatarInitial(auth.currentUserEmail)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'My Profile',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Role: ${role.label}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _permissionHint(role),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: _emailController,
                        readOnly: !canEditAll,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          helperText: 'Admin can edit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<UserRole>(
                        initialValue: _draftRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          helperText: 'Admin can edit',
                        ),
                        items: UserRole.values
                            .map(
                              (userRole) => DropdownMenuItem<UserRole>(
                                value: userRole,
                                child: Text(userRole.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: canEditAll
                            ? (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() => _draftRole = value);
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _organizationController,
                        readOnly: !canEditAll,
                        decoration: const InputDecoration(
                          labelText: 'Organization',
                          helperText: 'Admin can edit',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _teamController,
                        readOnly: !canEditAll,
                        decoration: const InputDecoration(
                          labelText: 'Team',
                          helperText: 'Admin can edit',
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Org chart lists other members in the same organization.
                      Row(
                        children: <Widget>[
                          Text(
                            'Org Chart',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${orgMembers.length})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canEditAll
                            ? 'Admin can edit team members in this organization.'
                            : 'Read-only view for non-admin users.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (orgMembers.isEmpty)
                        const Text(
                          'No other team members found in this organization.',
                        )
                      else
                        Column(
                          children: orgMembers
                              .map(
                                (member) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.account_tree_outlined,
                                    ),
                                    title: Text(member.email),
                                    subtitle: Text(
                                      'Role: ${member.role.label} | Team: ${member.teamId}',
                                    ),
                                    trailing: canEditAll
                                        ? IconButton(
                                            // Admin-only edit flow for org-chart members.
                                            onPressed: () =>
                                                _openOrgMemberEditor(member),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            tooltip: 'Edit member',
                                          )
                                        : null,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  if (canEditAll)
                    FilledButton.icon(
                      // Save is available only for admins.
                      onPressed: !_saving ? _saveProfile : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a member editor dialog and refreshes org chart after successful save.
  Future<void> _openOrgMemberEditor(MockUserProfile member) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _OrgMemberEditorDialog(member: member),
    );
    if (updated == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Org chart member updated')));
    }
  }

  /// Applies updates through `AuthProvider`, which also enforces role rules.
  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await auth.updateCurrentUserProfile(
        email: _emailController.text,
        role: _draftRole,
        organizationId: _organizationController.text,
        teamId: _teamController.text,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update profile')),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  /// Computes a safe avatar initial even when email data is missing.
  String _avatarInitial(String? email) {
    final normalized = email?.trim() ?? '';
    if (normalized.isEmpty) {
      return '?';
    }
    return normalized.substring(0, 1).toUpperCase();
  }

  /// Explains permission boundaries directly in the dialog for clarity.
  String _permissionHint(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin access: profile + org chart are editable.';
      case UserRole.manager:
        return 'Manager access: profile and org chart are read-only.';
      case UserRole.member:
        return 'Member access: profile and org chart are read-only.';
    }
  }
}

/// Admin-only editor for updating another user in the organization chart.
class _OrgMemberEditorDialog extends StatefulWidget {
  const _OrgMemberEditorDialog({required this.member});

  final MockUserProfile member;

  @override
  State<_OrgMemberEditorDialog> createState() => _OrgMemberEditorDialogState();
}

class _OrgMemberEditorDialogState extends State<_OrgMemberEditorDialog> {
  late final TextEditingController _organizationController;
  late final TextEditingController _teamController;
  late UserRole _draftRole;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fills editable fields from selected org-chart member details.
    _organizationController = TextEditingController(
      text: widget.member.organizationId,
    );
    _teamController = TextEditingController(text: widget.member.teamId);
    _draftRole = widget.member.role;
  }

  @override
  void dispose() {
    _organizationController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Team Member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              initialValue: widget.member.email,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<UserRole>(
              initialValue: _draftRole,
              decoration: const InputDecoration(labelText: 'Role'),
              items: UserRole.values
                  .map(
                    (role) => DropdownMenuItem<UserRole>(
                      value: role,
                      child: Text(role.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _draftRole = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _organizationController,
              decoration: const InputDecoration(labelText: 'Organization'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _teamController,
              decoration: const InputDecoration(labelText: 'Team'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Persists in the centralized mock directory for immediate app reuse.
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

  /// Writes member updates to mock directory and returns success to caller.
  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = updateMockUserProfileByEmail(
      email: widget.member.email,
      role: _draftRole,
      organizationId: _organizationController.text,
      teamId: _teamController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update team member')),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }
}
