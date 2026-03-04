class UserProfile {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}
