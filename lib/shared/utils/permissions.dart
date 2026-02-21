import '../../data/models/incident.dart';
import 'user_role.dart';

/// Centralized authorization checks used by screens/providers.
class PermissionPolicy {
  PermissionPolicy._();

  /// Admin, manager, and member can create incidents in this mock workflow.
  static bool canCreateIncident(UserRole role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.manager:
      case UserRole.member:
        return true;
    }
  }

  /// Access rules for viewing incidents by role and org/team/user scope.
  static bool canViewIncident({
    required UserRole role,
    required Incident incident,
    required String? currentUserEmail,
    required String? organizationId,
    required String? teamId,
  }) {
    final normalizedUser = currentUserEmail?.trim().toLowerCase();
    final normalizedAssigned = incident.assignedTo?.trim().toLowerCase();

    switch (role) {
      case UserRole.admin:
        return true;
      case UserRole.manager:
        final inOrganization = _equalsIgnoreCase(
          incident.organizationId,
          organizationId,
        );
        final ownTicket =
            normalizedUser != null &&
            normalizedUser.isNotEmpty &&
            normalizedAssigned == normalizedUser;
        return inOrganization || ownTicket;
      case UserRole.member:
        return _equalsIgnoreCase(incident.teamId, teamId);
    }
  }

  /// Edit rules where members can only edit their own assigned tickets.
  static bool canEditIncident({
    required UserRole role,
    required Incident incident,
    required String? currentUserEmail,
    required String? organizationId,
  }) {
    final normalizedUser = currentUserEmail?.trim().toLowerCase();
    final normalizedAssigned = incident.assignedTo?.trim().toLowerCase();

    switch (role) {
      case UserRole.admin:
        return true;
      case UserRole.manager:
        final inOrganization = _equalsIgnoreCase(
          incident.organizationId,
          organizationId,
        );
        final ownTicket =
            normalizedUser != null &&
            normalizedUser.isNotEmpty &&
            normalizedAssigned == normalizedUser;
        return inOrganization || ownTicket;
      case UserRole.member:
        return normalizedUser != null &&
            normalizedUser.isNotEmpty &&
            normalizedAssigned == normalizedUser;
    }
  }

  /// Assignment rules where members may only keep/unset their own ownership.
  static bool canAssignTo({
    required UserRole role,
    required String? currentUserEmail,
    required String? targetAssignee,
  }) {
    switch (role) {
      case UserRole.admin:
      case UserRole.manager:
        return true;
      case UserRole.member:
        final normalizedTarget = targetAssignee?.trim().toLowerCase();
        final normalizedUser = currentUserEmail?.trim().toLowerCase();
        return normalizedTarget == null ||
            normalizedTarget.isEmpty ||
            (normalizedUser != null && normalizedTarget == normalizedUser);
    }
  }

  /// Helper for case-insensitive string equality checks.
  static bool _equalsIgnoreCase(String? a, String? b) {
    return a?.trim().toLowerCase() == b?.trim().toLowerCase();
  }
}
