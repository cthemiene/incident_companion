import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/mock/mock_users.dart';
import '../../shared/utils/user_role.dart';
import 'auth_provider.dart';

/// Entry screen for mock sign-in flow.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _submitting = false;
  String _selectedEmail = defaultMockUserEmail;

  @override
  Widget build(BuildContext context) {
    final selectedProfile = defaultMockUserProfile(_selectedEmail);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF3F6FB), Color(0xFFEFF5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Incident Companion',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A ease of access-inspired workspace for incident handling.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        // Mock user picker to test Admin/Manager/Member behaviors.
                        DropdownButtonFormField<String>(
                          initialValue: _selectedEmail,
                          decoration: const InputDecoration(
                            labelText: 'Mock User',
                          ),
                          items: mockUserProfiles
                              .map(
                                (profile) => DropdownMenuItem<String>(
                                  value: profile.email,
                                  child: Text(profile.email),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() => _selectedEmail = value);
                                },
                        ),
                        const SizedBox(height: 10),
                        // Shows role and scope tied to the selected mock identity.
                        Text(
                          'Role: ${selectedProfile.role.label} | Org: ${selectedProfile.organizationId} | Team: ${selectedProfile.teamId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Mock authentication only. No live backend call is made.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    setState(() => _submitting = true);
                                    await context.read<AuthProvider>().signIn(
                                      email: _selectedEmail,
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    context.go('/incidents');
                                  },
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Sign in (mock)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
