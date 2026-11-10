class User {
  String? avatar;
  String? username;
  String? name;

  User({
    this.avatar,
    this.username,
    this.name,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? fullName;
    if (json['first_name'] != null || json['last_name'] != null) {
      fullName = '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim();
    } else if (json['name'] != null) {
      fullName = json['name'] as String?;
    } else if (json['title'] != null) {
      fullName = json['title'] as String?;
    }

    String? avatarUrl;
    if (json['avatar'] != null) {
      avatarUrl = json['avatar'] as String?;
    } else if (json['image'] is List && (json['image'] as List).isNotEmpty) {
      avatarUrl = json['image'][0]['link'] as String?;
    }

    return User(
      avatar: avatarUrl,
      username: (json['username'] ?? json['id'])?.toString(),
      name: fullName,
    );
  }
}
