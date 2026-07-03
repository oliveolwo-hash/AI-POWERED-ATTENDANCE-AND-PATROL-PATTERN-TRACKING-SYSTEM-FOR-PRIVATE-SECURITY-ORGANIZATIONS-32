enum UserRole { superAdmin, admin, guard }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'System Admin';
      case UserRole.admin:
        return 'Supervisor';
      case UserRole.guard:
        return 'Guard';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? orgId; // Null for admin, value for guard
  final String? orgName; // Name of the organization for guard
  final bool isApproved; // Only relevant for guard
  final bool isActive; // Track deactivation
  final Map<String, bool>? permissions; // Access control permissions for supervisors
  final String? phoneNumber;
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.orgId,
    this.orgName,
    this.isApproved = true, // Default to true for admin
    this.isActive = true, // Default to active
    this.permissions,
    this.phoneNumber,
    this.profileImageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name, // Will serialize to 'superAdmin', 'admin' or 'guard'
      'orgId': orgId,
      'orgName': orgName,
      'isApproved': isApproved,
      'isActive': isActive,
      'permissions': permissions,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Handle both new string roles and legacy integer roles for smooth transition
    UserRole parsedRole;
    final roleValue = map['role'];
    if (roleValue is String) {
      if (roleValue == 'superAdmin') {
        parsedRole = UserRole.superAdmin;
      } else if (roleValue == 'admin') {
        parsedRole = UserRole.admin;
      } else {
        parsedRole = UserRole.guard;
      }
    } else if (roleValue is int) {
      if (roleValue == 2) {
        parsedRole = UserRole.superAdmin;
      } else if (roleValue == 0) {
        parsedRole = UserRole.admin;
      } else {
        parsedRole = UserRole.guard; // 1 was personnel/guard
      }
    } else {
      parsedRole = UserRole.guard; // Fallback
    }

    Map<String, bool>? parsedPermissions;
    if (map['permissions'] != null) {
      try {
        parsedPermissions = Map<String, bool>.from(map['permissions']);
      } catch (e) {
        parsedPermissions = null;
      }
    }

    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: parsedRole,
      orgId: map['orgId'],
      orgName: map['orgName'],
      isApproved: map['isApproved'] ?? true,
      isActive: map['isActive'] ?? true,
      permissions: parsedPermissions,
      phoneNumber: map['phoneNumber'],
      profileImageUrl: map['profileImageUrl'],
    );
  }
}

