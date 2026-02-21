import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/mock/mock_users.dart';
import '../../data/models/incident.dart';
import '../../data/repositories/mock_incident_repository.dart';
import '../../data/mock/mock_scope_data.dart';
import '../../shared/utils/permissions.dart';
import '../../shared/utils/user_role.dart';
import '../auth/auth_provider.dart';
import '../my_items/my_items_provider.dart';
import 'incidents_provider.dart';
import 'widgets/assignee_selector_field.dart';

/// Form screen used to create a brand-new incident record.
class CreateIncidentScreen extends StatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  State<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();

  IncidentStatus _status = IncidentStatus.open;
  IncidentSeverity _severity = IncidentSeverity.s5;
  IncidentEnvironment _environment = IncidentEnvironment.prod;
  DateTime _createdAt = DateTime.now();
  DateTime _updatedAt = DateTime.now();
  bool _submitting = false;
  bool _loadingIncidentId = true;
  late final String _currentUserEmail;
  String? _selectedAssignee;
  bool _assigneeInputInvalid = false;

  @override
  void initState() {
    super.initState();
    // Cache current user for "Assign to me" behavior in shared selector.
    final authProvider = context.read<AuthProvider>();
    _currentUserEmail = authProvider.currentUserEmail ?? defaultMockUserEmail;
    // Preload the next available ID so users do not type IDs manually.
    _initializeIncidentId();
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  /// Loads the next incident number from the repository on screen startup.
  Future<void> _initializeIncidentId() async {
    try {
      final repository = context.read<MockIncidentRepository>();
      final nextIncidentId = await repository.generateNextIncidentId();
      if (!mounted) {
        return;
      }
      setState(() {
        _idController.text = nextIncidentId;
        _loadingIncidentId = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      // Keep form visible so users can continue filling fields while ID fails.
      setState(() => _loadingIncidentId = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: <Widget>[
            // Display-only ticket ID; internal UUID is generated on save.
            TextFormField(
              controller: _idController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Incident ID (auto)',
                hintText: 'Generating...',
                suffixIcon: Icon(Icons.lock_outline),
              ),
              validator: _requiredValidator('Incident ID'),
            ),
            const SizedBox(height: 12),
            // Short human-readable summary.
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: _requiredValidator('Title'),
            ),
            const SizedBox(height: 12),
            // Full narrative that explains impact and context.
            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: _requiredValidator('Description'),
            ),
            const SizedBox(height: 12),
            // Owning/impacted service.
            TextFormField(
              controller: _serviceController,
              decoration: const InputDecoration(labelText: 'Service'),
              validator: _requiredValidator('Service'),
            ),
            const SizedBox(height: 12),
            // Shared assignee selector to avoid duplicating assignment logic.
            AssigneeSelectorField(
              currentUserEmail: _currentUserEmail,
              onSelectedAssigneeChanged: (selectedAssignee) {
                _selectedAssignee = selectedAssignee;
              },
              onInvalidInputChanged: (invalid) {
                _assigneeInputInvalid = invalid;
              },
            ),
            const SizedBox(height: 12),
            // Incident workflow status.
            DropdownButtonFormField<IncidentStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: IncidentStatus.values
                  .map(
                    (status) => DropdownMenuItem<IncidentStatus>(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            // Business severity where S5 is the default lowest level.
            DropdownButtonFormField<IncidentSeverity>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: IncidentSeverity.values
                  .map(
                    (severity) => DropdownMenuItem<IncidentSeverity>(
                      value: severity,
                      child: Text(severity.name.toUpperCase()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _severity = value);
              },
            ),
            const SizedBox(height: 12),
            // Environment targeted by the incident.
            DropdownButtonFormField<IncidentEnvironment>(
              initialValue: _environment,
              decoration: const InputDecoration(labelText: 'Environment'),
              items: IncidentEnvironment.values
                  .map(
                    (environment) => DropdownMenuItem<IncidentEnvironment>(
                      value: environment,
                      child: Text(_environmentLabel(environment)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _environment = value);
              },
            ),
            const SizedBox(height: 12),
            // Editable created timestamp.
            _DateTimeField(
              label: 'Created At',
              value: _createdAt,
              onPick: (value) => setState(() => _createdAt = value),
            ),
            const SizedBox(height: 10),
            // Editable updated timestamp.
            _DateTimeField(
              label: 'Updated At',
              value: _updatedAt,
              onPick: (value) => setState(() => _updatedAt = value),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              // Submit is disabled until we have an auto-generated incident ID.
              onPressed:
                  (_submitting ||
                      _loadingIncidentId ||
                      _idController.text.trim().isEmpty)
                  ? null
                  : _saveIncident,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task),
              label: Text(_submitting ? 'Creating...' : 'Create Incident'),
            ),
          ],
        ),
      ),
    );
  }

  /// Common validator for required text fields.
  FormFieldValidator<String> _requiredValidator(String label) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$label is required';
      }
      return null;
    };
  }

  /// Persists the new incident and refreshes list views.
  Future<void> _saveIncident() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Guard save if ID generation failed unexpectedly.
    if (_idController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident ID could not be generated. Try again.'),
        ),
      );
      return;
    }
    if (_updatedAt.isBefore(_createdAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updated At cannot be earlier than Created At.'),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final repository = context.read<MockIncidentRepository>();
    final incidentsProvider = context.read<IncidentsProvider>();
    final myItemsProvider = context.read<MyItemsProvider>();
    final currentUser = authProvider.currentUserEmail;
    if (!PermissionPolicy.canCreateIncident(authProvider.currentUserRole)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to create incidents.'),
        ),
      );
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
    if (!PermissionPolicy.canAssignTo(
      role: authProvider.currentUserRole,
      currentUserEmail: currentUser,
      targetAssignee: _selectedAssignee,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your role can only assign to yourself or leave unassigned.',
          ),
        ),
      );
      return;
    }

    // Enter submitting state only after all synchronous validation passes.
    setState(() => _submitting = true);

    try {
      // Reserve sequence at submit time to avoid duplicate preview IDs.
      final reservedIncidentNumber = await repository
          .reserveNextIncidentNumber();
      final assignedProfile = findMockUserProfileByEmail(_selectedAssignee);
      final scopeOrganizationId = authProvider.currentUserRole == UserRole.admin
          ? (assignedProfile?.organizationId ??
                authProvider.currentOrganizationId ??
                defaultMockOrganizationId)
          : (authProvider.currentOrganizationId ?? defaultMockOrganizationId);
      final scopeTeamId = authProvider.currentUserRole == UserRole.admin
          ? (assignedProfile?.teamId ??
                authProvider.currentTeamId ??
                defaultMockTeamId)
          : (authProvider.currentTeamId ?? defaultMockTeamId);
      final incident = Incident(
        // Internal immutable ID for persistence/routing/backend alignment.
        id: const Uuid().v4(),
        incidentNumber: reservedIncidentNumber,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        status: _status,
        severity: _severity,
        service: _serviceController.text.trim(),
        organizationId: scopeOrganizationId,
        teamId: scopeTeamId,
        environment: _environment,
        createdAt: _createdAt,
        updatedAt: _updatedAt,
        assignedTo: _selectedAssignee,
      );

      await repository.createIncident(incident);
      await incidentsProvider.refresh();
      await myItemsProvider.loadMyItems(assignedTo: currentUser);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incident ${incident.displayId} created.')),
      );
      // Route directly to details for immediate verification/editing.
      context.go('/incidents/${incident.id}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      try {
        // Refresh preview because the reserved number may have been consumed.
        final nextIncidentId = await repository.generateNextIncidentId();
        if (mounted) {
          setState(() => _idController.text = nextIncidentId);
        }
      } catch (_) {
        // Preserve current UI state if refresh fails; error toast still shown.
      }
      // Ensure context is still valid after async preview refresh attempt.
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create incident: $error')),
      );
    }
  }

  /// Human-readable status label mapper.
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

  /// Human-readable environment label mapper.
  String _environmentLabel(IncidentEnvironment environment) {
    switch (environment) {
      case IncidentEnvironment.prod:
        return 'Production';
      case IncidentEnvironment.nonProd:
        return 'Non-Prod';
    }
  }
}

/// Reusable DateTime picker row used for created/updated fields.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        // First pick date, then pick time to build full timestamp.
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date == null || !context.mounted) {
          return;
        }
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value),
        );
        if (time == null) {
          return;
        }
        onPick(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        '$label: ${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
      ),
    );
  }
}
