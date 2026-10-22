enum UserRole { member, trainer, admin }

class User {
  final String id;
  final String email;
  final String username;
  final String name;

  /// Legal full name given at trainer sign-up (empty for members and for
  /// trainers who registered before the field existed).
  final String fullName;
  final UserRole role;
  final UserProfile? profile;
  final bool isEmailVerified;
  final bool isApproved;
  final String credentialImageUrl;
  final String? privateNotes;
  final String? bio;
  final String? trainer;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
    this.fullName = '',
    this.role = UserRole.member,
    this.profile,
    this.isEmailVerified = false,
    this.isApproved = false,
    this.credentialImageUrl = '',
    this.privateNotes,
    this.bio,
    this.trainer,
    this.lastSeen,
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

    final fullName = json['fullName']?.toString().trim() ?? '';

    return User(
      id: json['_id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      name:
          json['name'] ??
          (fullName.isNotEmpty ? fullName : null) ??
          json['username'] ??
          '',
      fullName: fullName,
      role: role,
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'])
          : null,
      isEmailVerified: json['isEmailVerified'] ?? false,
      isApproved: json['isApproved'] ?? false,
      credentialImageUrl: json['credentialImageUrl'] ?? '',
      privateNotes: json['privateNotes'],
      bio: json['bio'],
      trainer: json['trainer'],
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'email': email,
      'username': username,
      'name': name,
      'fullName': fullName,
      'role': role.toString().split('.').last,
      'profile': profile?.toJson(),
      'isEmailVerified': isEmailVerified,
      'isApproved': isApproved,
      'credentialImageUrl': credentialImageUrl,
      'privateNotes': privateNotes,
      'bio': bio,
      'trainer': trainer,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}

class UserProfile {
  final String? firstName;
  final String? lastName;

  UserProfile({this.firstName, this.lastName});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firstName: json['firstName'],
      lastName: json['lastName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'firstName': firstName, 'lastName': lastName};
  }
}
