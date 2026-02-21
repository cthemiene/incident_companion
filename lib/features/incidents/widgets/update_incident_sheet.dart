import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/incident.dart';
import '../../../data/models/incident_update.dart';
import '../../../data/repositories/mock_incident_repository.dart';
import '../../auth/auth_provider.dart';
import '../../outbox/outbox_provider.dart';

/// Bottom sheet used to queue incident updates (status, assignment, comment).
class UpdateIncidentSheet extends StatefulWidget {
  const UpdateIncidentSheet({
    super.key,
    required this.incidentId,
    this.initialAssignedTo,
    this.onQueuedUpdate,
  });

  final String incidentId;
  final String? initialAssignedTo;
  final ValueChanged<IncidentUpdate>? onQueuedUpdate;

  @override
  State<UpdateIncidentSheet> createState() => _UpdateIncidentSheetState();
}

class _UpdateIncidentSheetState extends State<UpdateIncidentSheet> {
  static const List<String> _defaultAssignableUsers = <String>[
    'engineer1@example.com',
    'engineer2@example.com',
    'engineer3@example.com',
    'engineer4@example.com',
    'engineer5@example.com',
  ];

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _assigneeSearchController =
      TextEditingController();

  IncidentStatus? _newStatus;
  IncidentVisibility _visibility = IncidentVisibility.workNotes;
  bool _submitting = false;

  late final String _currentUserEmail;
  late final List<String> _assignableUsers;
  String? _selectedAssignee;

  /// Seeds assignable users and restores initial assignee state.
  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _currentUserEmail =
        authProvider.currentUserEmail ?? 'engineer1@example.com';
    _assignableUsers = _buildAssignableUsers(_currentUserEmail);

    final initial = widget.initialAssignedTo?.trim();
    if (initial != null &&
        initial.isNotEmpty &&
        !_assignableUsers.contains(initial)) {
      _assignableUsers.insert(1, initial);
    }

    if (initial != null && initial.isNotEmpty) {
      _selectedAssignee = initial;
      _assigneeSearchController.text = initial;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _assigneeSearchController.dispose();
    super.dispose();
  }

  /// Builds search results with "Assign to me" and "Unassigned" helpers.
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final searchQuery = _assigneeSearchController.text.trim();
    final matches = _matchingUsers(searchQuery);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Update incident',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<IncidentStatus?>(
              initialValue: _newStatus,
              decoration: const InputDecoration(
                labelText: 'Status change (optional)',
              ),
              items: <DropdownMenuItem<IncidentStatus?>>[
                const DropdownMenuItem<IncidentStatus?>(
                  value: null,
                  child: Text('No status change'),
                ),
                ...IncidentStatus.values.map(
                  (status) => DropdownMenuItem<IncidentStatus?>(
                    value: status,
                    child: Text(_labelForStatus(status)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _newStatus = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _assigneeSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Assign to (search)',
                hintText: 'Type a user email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _assigneeSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _assigneeSearchController.clear();
                          setState(() {
                            _selectedAssignee = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedAssignee = _currentUserEmail;
                      _assigneeSearchController.text = _currentUserEmail;
                    });
                  },
                  icon: const Icon(Icons.person, size: 16),
                  label: const Text('Assign to me'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _assigneeSearchController.clear();
                    setState(() => _selectedAssignee = null);
                  },
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: const Text('Unassigned'),
                ),
              ],
            ),
            if (_selectedAssignee != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'Selected: $_selectedAssignee',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (searchQuery.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              if (matches.isEmpty)
                Text(
                  'No matches found.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final user = matches[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            user == _currentUserEmail
                                ? Icons.person
                                : Icons.person_outline,
                            size: 18,
                          ),
                          title: Text(
                            user == _currentUserEmail ? 'Me ($user)' : user,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedAssignee = user;
                              _assigneeSearchController.text = user;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<IncidentVisibility>(
              segments: const <ButtonSegment<IncidentVisibility>>[
                ButtonSegment<IncidentVisibility>(
                  value: IncidentVisibility.workNotes,
                  label: Text('Work notes'),
                ),
                ButtonSegment<IncidentVisibility>(
                  value: IncidentVisibility.customerVisible,
                  label: Text('Customer visible'),
                ),
              ],
              selected: <IncidentVisibility>{_visibility},
              onSelectionChanged: (selected) {
                setState(() => _visibility = selected.first);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'Required',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _onSave,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save (Queue)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Ensures current user appears first in the assignable list.
  List<String> _buildAssignableUsers(String currentUserEmail) {
    final users = <String>[currentUserEmail];
    for (final user in _defaultAssignableUsers) {
      if (user != currentUserEmail) {
        users.add(user);
      }
    }
    return users;
  }

  /// Returns users whose email contains the entered query.
  List<String> _matchingUsers(String query) {
    if (query.isEmpty) {
      return const <String>[];
    }
    final normalized = query.toLowerCase();
    return _assignableUsers
        .where((user) => user.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  /// Converts status enum to dropdown labels.
  String _labelForStatus(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.open:
        return 'Open';
      case IncidentStatus.inProgress:
        return 'In Progress';
      case IncidentStatus.resolved:
        return 'Resolved';
    }
  }

  /// Validates inputs, queues update, and applies local optimistic changes.
  Future<void> _onSave() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment is required.')));
      return;
    }

    final assigneeInput = _assigneeSearchController.text.trim();
    if (assigneeInput.isNotEmpty) {
      final exactMatch = _assignableUsers.firstWhere(
        (user) => user.toLowerCase() == assigneeInput.toLowerCase(),
        orElse: () => '',
      );
      if (exactMatch.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select a user from search results or clear assignee.',
            ),
          ),
        );
        return;
      }
      _selectedAssignee = exactMatch;
    } else {
      _selectedAssignee = null;
    }

    setState(() => _submitting = true);

    final repository = context.read<MockIncidentRepository>();
    final outboxProvider = context.read<OutboxProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final update = IncidentUpdate(
      id: const Uuid().v4(),
      incidentId: widget.incidentId,
      newStatus: _newStatus,
      assignedTo: _selectedAssignee,
      comment: _commentController.text.trim(),
      visibility: _visibility,
      createdAt: DateTime.now(),
      syncState: SyncState.pending,
    );

    try {
      await repository.queueUpdate(update);
      await repository.applyUpdateLocally(update);
      await outboxProvider.loadOutbox();
      widget.onQueuedUpdate?.call(update);

      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('Update queued')));
      navigator.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to queue update: $error')),
      );
    }
  }
}
