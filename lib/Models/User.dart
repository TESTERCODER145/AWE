// user_model.dart
class User {
  final int? id;
  final String? email;
  final UserRole role;
  final Map<String, dynamic>? userData;

  User({
    this.id,
    this.email,
    this.role = UserRole.guest,
    this.userData,
  });
  // Add to User class
  User copyWith({
    Map<String, dynamic>? userData,
  }) {
    return User(
      id: userData?['id'] ?? this.id,
      email: userData?['email'] ?? this.email,
      role: this.role,
      userData: userData ?? this.userData,
    );
  }

  bool canAccess(Feature feature) {
    return feature.allowedRoles.contains(role);
  }
}

enum UserRole {
  guest,
  authenticated
}

class Feature {
  final String name;
  final Set<UserRole> allowedRoles;

  const Feature({
    required this.name,
    required this.allowedRoles,
  });
}