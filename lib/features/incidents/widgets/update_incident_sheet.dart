import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/mock/mock_users.dart';
import '../../../data/models/incident.dart';
import '../../../data/models/incident_update.dart';
import '../../../data/repositories/mock_incident_repository.dart';
import '../../auth/auth_provider.dart';
import '../../outbox/outbox_provider.dart';
import 'assignee_selector_field.dart';

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
  final TextEditingController _commentController = TextEditingController();

  IncidentStatus? _newStatus;
  IncidentVisibility _visibility = IncidentVisibility.workNotes;
  bool _submitting = false;

  late final String _currentUserEmail;
  String? _selectedAssignee;
  bool _assigneeInputInvalid = false;

  /// Captures current user and optional initial assignee.
  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _currentUserEmail = authProvider.currentUserEmail ?? defaultMockUserEmail;
    // Preserve existing assignment when opening the update sheet.
    _selectedAssignee = widget.initialAssignedTo?.trim();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
            // Shared assignee selector keeps create/update behavior consistent.
            AssigneeSelectorField(
              currentUserEmail: _currentUserEmail,
              initialAssignee: widget.initialAssignedTo,
              onSelectedAssigneeChanged: (selectedAssignee) {
                _selectedAssignee = selectedAssignee;
              },
              onInvalidInputChanged: (invalid) {
                _assigneeInputInvalid = invalid;
              },
            ),
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

    if (_assigneeInputInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a user from search results or clear assignee.'),
        ),
      );
      return;
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
