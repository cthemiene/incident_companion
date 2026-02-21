import 'package:flutter/material.dart';

import '../../../data/mock/mock_users.dart';

/// Reusable search-based assignee selector used by create/update flows.
class AssigneeSelectorField extends StatefulWidget {
  const AssigneeSelectorField({
    super.key,
    required this.currentUserEmail,
    required this.onSelectedAssigneeChanged,
    this.onInvalidInputChanged,
    this.initialAssignee,
    this.labelText = 'Assign to (search)',
    this.hintText = 'Type a user email',
  });

  final String currentUserEmail;
  final String? initialAssignee;
  final String labelText;
  final String hintText;
  final ValueChanged<String?> onSelectedAssigneeChanged;
  final ValueChanged<bool>? onInvalidInputChanged;

  @override
  State<AssigneeSelectorField> createState() => _AssigneeSelectorFieldState();
}

class _AssigneeSelectorFieldState extends State<AssigneeSelectorField> {
  late final TextEditingController _searchController;
  late final List<String> _assignableUsers;
  String? _selectedAssignee;

  @override
  void initState() {
    super.initState();
    _assignableUsers = _buildAssignableUsers(
      currentUserEmail: widget.currentUserEmail,
      initialAssignee: widget.initialAssignee,
    );
    _searchController = TextEditingController(
      text: widget.initialAssignee?.trim() ?? '',
    );
    _syncSelectionFromInput(notifyParent: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Builds the assignable list with current user first and optional initial.
  List<String> _buildAssignableUsers({
    required String currentUserEmail,
    required String? initialAssignee,
  }) {
    final users = <String>[currentUserEmail];
    for (final user in mockUserEmails) {
      if (user.toLowerCase() != currentUserEmail.toLowerCase()) {
        users.add(user);
      }
    }

    final normalizedInitial = initialAssignee?.trim();
    if (normalizedInitial != null &&
        normalizedInitial.isNotEmpty &&
        !users.any(
          (user) => user.toLowerCase() == normalizedInitial.toLowerCase(),
        )) {
      users.insert(1, normalizedInitial);
    }

    return users;
  }

  /// Returns directory matches for non-empty search input.
  List<String> _matchingUsers(String query) {
    if (query.isEmpty) {
      return const <String>[];
    }
    final normalized = query.toLowerCase();
    return _assignableUsers
        .where((user) => user.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  /// Syncs selected assignee and invalid-input state from current search text.
  void _syncSelectionFromInput({required bool notifyParent}) {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      _selectedAssignee = null;
      if (notifyParent) {
        widget.onSelectedAssigneeChanged(null);
        widget.onInvalidInputChanged?.call(false);
      }
      return;
    }

    final exactMatch = _assignableUsers
        .where((user) {
          return user.toLowerCase() == input.toLowerCase();
        })
        .toList(growable: false);

    _selectedAssignee = exactMatch.isEmpty ? null : exactMatch.first;

    if (notifyParent) {
      widget.onSelectedAssigneeChanged(_selectedAssignee);
      widget.onInvalidInputChanged?.call(_selectedAssignee == null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.trim();
    final matches = _matchingUsers(searchQuery);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _searchController,
          onChanged: (_) {
            setState(() {
              _syncSelectionFromInput(notifyParent: true);
            });
          },
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _syncSelectionFromInput(notifyParent: true);
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
                _searchController.text = widget.currentUserEmail;
                setState(() {
                  _syncSelectionFromInput(notifyParent: true);
                });
              },
              icon: const Icon(Icons.person, size: 16),
              label: const Text('Assign to me'),
            ),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _syncSelectionFromInput(notifyParent: true);
                });
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
                        user == widget.currentUserEmail
                            ? Icons.person
                            : Icons.person_outline,
                        size: 18,
                      ),
                      title: Text(
                        user == widget.currentUserEmail ? 'Me ($user)' : user,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () {
                        _searchController.text = user;
                        setState(() {
                          _syncSelectionFromInput(notifyParent: true);
                        });
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }
}
