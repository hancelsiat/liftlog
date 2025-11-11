enum UserRole {
  member,
  trainer,
  admin
}

class User {
  final String id;
  final String email;
  final String username;
  final String name;
  final UserRole role;
  final UserProfile? profile;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
    this.role = UserRole.member,
    this.profile,
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
      username: json['username'] ?? '',
      name: json['name'] ?? json['username'] ?? '',
      role: role,
      profile: json['profile'] != null ? UserProfile.fromJson(json['profile']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'username': username,
      'name': name,
      'role': role.toString().split('.').last,
      'profile': profile?.toJson(),
    };
  }
}

class UserProfile {
  final String? firstName;
  final String? lastName;

  UserProfile({
    this.firstName,
    this.lastName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firstName: json['firstName'],
      lastName: json['lastName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}
