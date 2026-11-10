class UserModel {
  String? id;
  String? username;
  String? name;
  String? email;
  String? city;
  String? avatar;

  UserModel({
    this.id,
    this.username,
    this.name,
    this.email,
    this.city,
    this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? fullName;
    if (json['first_name'] != null || json['last_name'] != null) {
      fullName = '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim();
    } else if (json['name'] != null) {
      fullName = json['name'] as String?;
    }

    String? avatarUrl;
    if (json['avatar'] != null) {
      avatarUrl = json['avatar'] as String?;
    } else if (json['image'] is List && (json['image'] as List).isNotEmpty) {
      avatarUrl = json['image'][0]['link'] as String?;
    }

    return UserModel(
      id: json['id']?.toString(),
      username: (json['username'] ?? json['id'])?.toString(),
      name: fullName,
      email: json['email'] as String?,
      city: json['city'] as String?,
      avatar: avatarUrl,
    );
  }
}
