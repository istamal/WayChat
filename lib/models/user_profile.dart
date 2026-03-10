class UserProfile {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool? isOnline;

  UserProfile({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isOnline,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? json['online'],
    );
  }

  String get displayNameOrUsername {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return username;
  }
}
