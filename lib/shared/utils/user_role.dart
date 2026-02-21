/// Supported application roles for ticket access and management rules.
enum UserRole { admin, manager, member }

/// User-friendly role labels for UI copy.
extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.member:
        return 'Member';
    }
  }
}

/// Storage helpers for role persistence in Hive auth box.
extension UserRoleStorage on UserRole {
  String get storageValue => name;

  static UserRole fromStorage(String? rawValue) {
    for (final role in UserRole.values) {
      if (role.name == rawValue) {
        return role;
      }
    }
    return UserRole.member;
  }
}
