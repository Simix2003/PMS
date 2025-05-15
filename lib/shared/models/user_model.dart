class UserModel {
  final String badgeId;
  final String name;
  final String email;
  final String role;
  bool isLoggedIn;

  UserModel({
    required this.badgeId,
    required this.name,
    required this.email,
    required this.role,
    this.isLoggedIn = false,
  });

  /// Marks the user as logged in
  void login() {
    isLoggedIn = true;
  }

  /// Marks the user as logged out
  void logout() {
    isLoggedIn = false;
  }

  /// Checks if the user has a specific permission
  bool can(String permission) {
    final permissions = _rolePermissions[role] ?? [];
    return permissions.contains(permission);
  }

  /// Creates a UserModel from a JSON map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      badgeId: json['id'] ?? '', // assuming 'id' refers to badgeId
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'guest',
      isLoggedIn: json['isLoggedIn'] ?? false,
    );
  }

  /// Converts a UserModel to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': badgeId,
      'name': name,
      'email': email,
      'role': role,
      'isLoggedIn': isLoggedIn,
    };
  }
}

/// Permissions assigned to each role
final Map<String, List<String>> _rolePermissions = {
  'simix': [
    'view_dashboard',
    'manage_users',
    'export_data',
    'edit_settings',
    'inspect_module',
    'rework_module',
    'EVERYTHING',
  ],
  'admin': [
    'view_dashboard',
    'manage_users',
    'export_data',
    'edit_settings',
    'inspect_module',
    'rework_module',
  ],
  'qc_operator': [
    'view_dashboard',
    'inspect_module',
  ],
  'rework_operator': [
    'view_dashboard',
    'rework_module',
  ],
  'guest': [
    // minimal or no permissions
  ],
};
