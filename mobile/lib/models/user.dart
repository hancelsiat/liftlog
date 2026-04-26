
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
  final bool isEmailVerified;
  final bool isApproved;
  final String credentialImageUrl;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
    this.role = UserRole.member,
    this.profile,
    this.isEmailVerified = false,
    this.isApproved = false,
    this.credentialImageUrl = ''
  });

  factory User.fromJson(Map<String, dynamic> json) {
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
      isEmailVerified: json['isEmailVerified'] ?? false,
      isApproved: json['isApproved'] ?? false,
      credentialImageUrl: json['credentialImageUrl'] ?? '',
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
      'isEmailVerified': isEmailVerified,
      'isApproved': isApproved,
      'credentialImageUrl': credentialImageUrl,
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
