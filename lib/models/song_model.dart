class SongModel {
  String? songid;
  String? songname;
  String? userid;
  String? trackid;
  String? duration;
  String? coverImageUrl;
  String? name;
  String? type;

  SongModel({
    this.songid,
    this.songname,
    this.userid,
    this.trackid,
    this.duration,
    this.coverImageUrl,
    this.name,
    this.type,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    String? fullName;
    if (json['first_name'] != null || json['last_name'] != null) {
      fullName = '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim();
    } else if (json['subtitle'] != null) {
      fullName = json['subtitle'] as String?;
    } else if (json['name'] != null) {
      fullName = json['name'] as String?;
    }

    String? cover;
    if (json['cover_image_url'] != null) {
      cover = json['cover_image_url'] as String?;
    } else if (json['image'] is List && (json['image'] as List).isNotEmpty) {
      cover = json['image'][0]['link'] as String?;
    }

    return SongModel(
      songid: (json['songid'] ?? json['id'])?.toString(),
      songname: (json['songname'] ?? json['title'] ?? json['name'])?.toString(),
      userid: json['userid']?.toString(),
      trackid: (json['trackid'] ?? json['id'])?.toString(),
      duration: json['duration']?.toString(),
      coverImageUrl: cover,
      name: fullName,
      type: json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'songid': songid,
        'songname': songname,
        'userid': userid,
        'trackid': trackid,
        'duration': duration,
        'cover_image_url': coverImageUrl,
        'name': name,
        'type': type,
      };
}
