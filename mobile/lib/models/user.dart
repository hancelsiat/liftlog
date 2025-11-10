enum UserRole {
  member,
  trainer,
  admin
}

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;

  User({
    required this.id, 
    required this.email, 
    required this.name,
    this.role = UserRole.member
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Convert string role to enum, default to member if not specified
    UserRole role;
    switch (json['role']?.toLowerCase()) {
      case 'trainer':
        role = UserRole.trainer;
        break;
      case 'admin':
        role = UserRole.admin;
        break;
      default:
        role = UserRole.member;
    }

    return User(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      name: json['username'] ?? json['name'] ?? '',
      role: role,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
    };
  }
}