import 'dart:convert';

import 'package:html_unescape/html_unescape.dart';

final _htmlDecoder = HtmlUnescape();
String _decode(String s) {
  if (s.isEmpty) return s;
  if (!s.contains('&')) return s;
  return _htmlDecoder.convert(s);
}

String? _decodeNullable(Object? s) {
  if (s == null) return null;
  final str = s.toString();
  return _decode(str);
}

String _decodeUnicodeEscapes(String s) {
  if (s.isEmpty) return s;
  var out = s;
  if (out.contains(r'\u')) {
    out = out.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
  }
  if (out.contains(r'\n') || out.contains(r'\r') || out.contains(r'\t')) {
    out = out
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\t', '\t');
  }
  return out;
}

String? _normalizeArtistBio(Object? raw) {
  if (raw == null) return null;

  if (raw is List) {
    return _joinBioSegments(raw);
  }

  final str = raw.toString().trim();
  if (str.isEmpty) return null;

  if (str.startsWith('[')) {
    try {
      final parsed = jsonDecode(str);
      if (parsed is List) {
        final joined = _joinBioSegments(parsed);
        if (joined != null && joined.isNotEmpty) return joined;
      }
    } catch (_) {
    }
  }

  return _decodeUnicodeEscapes(_decode(str));
}

String? _joinBioSegments(List<dynamic> segments) {
  final entries =
      segments
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .where((m) => (m['text'] ?? '').toString().trim().isNotEmpty)
          .toList()
        ..sort((a, b) {
          final sa = (a['sequence'] as num?)?.toInt() ?? 0;
          final sb = (b['sequence'] as num?)?.toInt() ?? 0;
          return sa.compareTo(sb);
        });
  if (entries.isEmpty) return null;
  return entries
      .map((m) => _decodeUnicodeEscapes(_decode(m['text'].toString().trim())))
      .join('\n\n');
}

class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.status,
    required this.message,
    required this.data,
    this.source,
    this.error,
  });

  final String status;
  final String message;
  final T? data;
  final String? source;
  final Object? error;

  bool get isSuccess => status == 'success';

  static ApiEnvelope<T> from<T>(
    Map<String, dynamic> json,
    T Function(Object? data) parseData,
  ) {
    return ApiEnvelope<T>(
      status: json['status'] as String? ?? 'failed',
      message: json['message'] as String? ?? '',
      data: parseData(json['data']),
      source: json['source'] as String?,
      error: json['error'],
    );
  }
}

class ApiImage {
  const ApiImage({required this.quality, required this.link});
  final String quality;
  final String link;

  factory ApiImage.fromJson(Map<String, dynamic> j) => ApiImage(
    quality: j['quality'] as String? ?? '',
    link: j['link'] as String? ?? '',
  );

  static List<ApiImage> listFrom(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => ApiImage.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return [ApiImage(quality: 'default', link: raw)];
    }
    return const [];
  }
}

class ApiArtistRef {
  const ApiArtistRef({required this.id, required this.name, this.image});
  final String id;
  final String name;
  final List<ApiImage>? image;

  factory ApiArtistRef.fromJson(Map<String, dynamic> j) => ApiArtistRef(
    id: (j['id'] ?? '').toString(),
    name: _decode((j['name'] ?? '').toString()),
    image: j['image'] == null ? null : ApiImage.listFrom(j['image']),
  );

  static List<ApiArtistRef> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ApiArtistRef.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

class ApiLanguage {
  const ApiLanguage({required this.name, required this.value});
  final String name;
  final String value;

  factory ApiLanguage.fromJson(Map<String, dynamic> j) => ApiLanguage(
    name: _decode((j['name'] ?? '').toString()),
    value: (j['value'] ?? '').toString(),
  );
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.title,
    required this.type,
    required this.image,
    this.subtitle,
    this.source,
    this.language,
    this.url,
    this.duration,
    this.songCount,
    this.playCount,
    this.releaseDate,
    this.artists,
    this.token,
    this.stationType,
    this.mediaUrls = const [],
  });

  final String id;
  final String title;
  final String? subtitle;
  final String type;
  final List<ApiImage> image;
  final String? source;
  final String? language;
  final String? url;
  final String? duration;
  final String? songCount;
  final String? playCount;
  final String? releaseDate;
  final List<ApiArtistRef>? artists;
  final String? token;

  final String? stationType;

  final List<ApiImage> mediaUrls;

  String? get displaySubtitle {
    final fromApi = (subtitle ?? '').trim();
    if (fromApi.isNotEmpty) return fromApi;

    final names = (artists ?? const <ApiArtistRef>[])
        .map((a) => a.name.trim())
        .where((n) => n.isNotEmpty)
        .take(2)
        .toList();
    if (names.isNotEmpty) return names.join(', ');

    switch (type) {
      case 'song':
        final yr = (releaseDate ?? '').trim();
        return yr.isEmpty ? (language ?? 'Song') : yr;
      case 'album':
        final yr = (releaseDate ?? '').trim();
        return yr.isEmpty ? (language ?? 'Album') : yr;
      case 'playlist':
        final n = (songCount ?? '').trim();
        return n.isEmpty ? 'Playlist' : '$n tracks';
      case 'channel':
      case 'radio_station':
      case 'radio':
        final lang = (language ?? '').trim();
        return lang.isEmpty ? 'Radio' : lang;
      case 'artist':
        return null;
      case 'occasion':
        return 'Mood';
      default:
        if (type.isEmpty) return null;
        final cleaned = type.replaceAll('_', ' ');
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }

  String? get artwork {
    if (image.isEmpty) return null;
    int score(String q) {
      final m = RegExp(r'(\d+)').firstMatch(q);
      return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
    }

    final sorted = [...image]
      ..sort((a, b) => score(b.quality).compareTo(score(a.quality)));
    return sorted.first.link;
  }

  Uri? get artworkUri {
    final art = artwork;
    if (art == null || art.isEmpty) return null;
    if (art.startsWith('/')) return Uri.file(art);
    return Uri.tryParse(art);
  }

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    id: (j['id'] ?? '').toString(),
    title: _decode((j['title'] ?? j['name'] ?? '').toString()),
    subtitle: _decodeNullable(j['subtitle']),
    type: (j['type'] ?? 'unknown').toString(),
    image: ApiImage.listFrom(j['image']),
    source: (j['source'] ?? j['provider'])?.toString(),
    language: _decodeNullable(j['language']),
    url: j['url']?.toString(),
    duration: j['duration']?.toString(),
    songCount: j['songCount']?.toString(),
    playCount: j['playCount']?.toString(),
    releaseDate: j['releaseDate']?.toString(),
    artists: j['artists'] == null ? null : ApiArtistRef.listFrom(j['artists']),
    token: j['token']?.toString(),
    stationType: j['stationType']?.toString(),
    mediaUrls: ApiImage.listFrom(j['mediaUrls']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'type': type,
    'image': image.map((i) => {'quality': i.quality, 'link': i.link}).toList(),
    if (source != null) 'source': source,
    if (language != null) 'language': language,
    if (url != null) 'url': url,
    if (duration != null) 'duration': duration,
    if (songCount != null) 'songCount': songCount,
    if (playCount != null) 'playCount': playCount,
    if (releaseDate != null) 'releaseDate': releaseDate,
    if (artists != null)
      'artists': artists!
          .map(
            (a) => {
              'id': a.id,
              'name': a.name,
              if (a.image != null)
                'image': a.image!
                    .map((i) => {'quality': i.quality, 'link': i.link})
                    .toList(),
            },
          )
          .toList(),
    if (token != null) 'token': token,
    if (stationType != null) 'stationType': stationType,
    if (source == 'podcastindex' && mediaUrls.isNotEmpty)
      'mediaUrls': mediaUrls
          .map((i) => {'quality': i.quality, 'link': i.link})
          .toList(),
  };
}

class HomeSection {
  const HomeSection({required this.heading, required this.items, this.source});

  final String heading;
  final List<FeedItem> items;
  final String? source;

  factory HomeSection.fromJson(Map<String, dynamic> j) => HomeSection(
    heading: _decode((j['heading'] ?? '').toString()),
    source: j['source']?.toString(),
    items: (j['data'] is List)
        ? (j['data'] as List)
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const [],
  );
}

typedef ApiSong = FeedItem;

class AlbumDetail {
  const AlbumDetail({
    required this.id,
    required this.title,
    required this.image,
    required this.artists,
    required this.songs,
    required this.sections,
    this.subtitle,
    this.year,
    this.songCount,
    this.releaseDate,
    this.language,
    this.description,
    this.source,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? year;
  final String? songCount;
  final String? releaseDate;
  final String? language;
  final String? description;
  final String? source;
  final List<ApiImage> image;
  final List<ApiArtistRef> artists;
  final List<ApiSong> songs;

  final List<HomeSection> sections;

  String? get artwork {
    if (image.isEmpty) return null;
    final sorted = [...image];
    int score(String q) {
      final m = RegExp(r'(\d+)').firstMatch(q);
      return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
    }

    sorted.sort((a, b) => score(b.quality).compareTo(score(a.quality)));
    return sorted.first.link;
  }

  String get metaLine {
    final parts = <String>[];
    if (artists.isNotEmpty) {
      parts.add(
        artists
            .take(2)
            .map((a) => a.name)
            .where((n) => n.isNotEmpty)
            .join(', '),
      );
    }
    if ((year ?? '').isNotEmpty) {
      parts.add(year!);
    } else if ((releaseDate ?? '').isNotEmpty) {
      parts.add(releaseDate!);
    }
    if ((songCount ?? '').isNotEmpty) parts.add('$songCount tracks');
    return parts.join(' · ');
  }

  factory AlbumDetail.fromJson(Map<String, dynamic> j) {
    final inner = (j['album'] is Map)
        ? (j['album'] as Map).cast<String, dynamic>()
        : (j['playlist'] is Map)
        ? (j['playlist'] as Map).cast<String, dynamic>()
        : j;
    final sectionsRaw = j['sections'] ?? inner['sections'];
    return AlbumDetail(
      id: (inner['id'] ?? '').toString(),
      title: _decode((inner['title'] ?? inner['name'] ?? '').toString()),
      subtitle: _decodeNullable(inner['subtitle']),
      year: inner['year']?.toString(),
      songCount: inner['songCount']?.toString(),
      releaseDate: inner['releaseDate']?.toString(),
      language: _decodeNullable(inner['language']),
      description: _decodeNullable(inner['description'] ?? inner['headerDesc']),
      source: inner['source']?.toString(),
      image: ApiImage.listFrom(inner['image']),
      artists: ApiArtistRef.listFrom(inner['artists']),
      songs: _feedItemList(inner['songs']),
      sections: _sectionList(sectionsRaw),
    );
  }
}

List<FeedItem> _feedItemList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
      .toList();
}

List<HomeSection> _sectionList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => HomeSection.fromJson(m.cast<String, dynamic>()))
      .where((s) => s.items.isNotEmpty)
      .toList();
}

class PlaylistDetail {
  const PlaylistDetail({
    required this.id,
    required this.title,
    required this.image,
    required this.songs,
    required this.sections,
    this.subtitle,
    this.songCount,
    this.followers,
    this.description,
    this.source,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? songCount;
  final String? followers;
  final String? description;
  final String? source;
  final List<ApiImage> image;
  final List<ApiSong> songs;

  final List<HomeSection> sections;

  String? get artwork {
    if (image.isEmpty) return null;
    final sorted = [...image];
    int score(String q) {
      final m = RegExp(r'(\d+)').firstMatch(q);
      return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
    }

    sorted.sort((a, b) => score(b.quality).compareTo(score(a.quality)));
    return sorted.first.link;
  }

  String get metaLine {
    final parts = <String>[];
    if ((subtitle ?? '').isNotEmpty) parts.add(subtitle!);
    if ((songCount ?? '').isNotEmpty) parts.add('$songCount tracks');
    if ((followers ?? '').isNotEmpty) parts.add('$followers followers');
    return parts.join(' · ');
  }

  factory PlaylistDetail.fromJson(Map<String, dynamic> j) {
    final inner = (j['playlist'] is Map)
        ? (j['playlist'] as Map).cast<String, dynamic>()
        : (j['album'] is Map)
        ? (j['album'] as Map).cast<String, dynamic>()
        : j;
    final sectionsRaw = j['sections'] ?? inner['sections'];
    return PlaylistDetail(
      id: (inner['id'] ?? '').toString(),
      title: _decode((inner['title'] ?? inner['name'] ?? '').toString()),
      subtitle: _decodeNullable(inner['subtitle']),
      songCount: inner['songCount']?.toString(),
      followers: inner['followers']?.toString(),
      description: _decodeNullable(inner['description']),
      source: inner['source']?.toString(),
      image: ApiImage.listFrom(inner['image']),
      songs: _feedItemList(inner['songs']),
      sections: _sectionList(sectionsRaw),
    );
  }
}

class ArtistDetail {
  const ArtistDetail({
    required this.id,
    required this.name,
    required this.image,
    required this.topSongs,
    required this.albums,
    required this.sections,
    this.subtitle,
    this.role,
    this.followers,
    this.bio,
    this.songCount,
    this.albumCount,
    this.source,
  });

  final String id;
  final String name;
  final String? subtitle;
  final String? role;
  final String? followers;
  final String? bio;
  final String? songCount;
  final String? albumCount;
  final String? source;
  final List<ApiImage> image;
  final List<ApiSong> topSongs;
  final List<FeedItem> albums;
  final List<HomeSection> sections;

  String? get artwork {
    if (image.isEmpty) return null;
    final sorted = [...image];
    int score(String q) {
      final m = RegExp(r'(\d+)').firstMatch(q);
      return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
    }

    sorted.sort((a, b) => score(b.quality).compareTo(score(a.quality)));
    return sorted.first.link;
  }

  factory ArtistDetail.fromJson(Map<String, dynamic> j) {
    final inner = (j['artist'] is Map)
        ? (j['artist'] as Map).cast<String, dynamic>()
        : j;

    List<FeedItem> listFrom(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    final allSections = _sectionList(inner['sections']);

    bool matchesHeading(String h, List<String> needles) {
      final low = h.toLowerCase();
      return needles.any(low.contains);
    }

    HomeSection? findFirst(bool Function(HomeSection) test) {
      for (final s in allSections) {
        if (test(s)) return s;
      }
      return null;
    }

    final songsSection = findFirst(
      (s) =>
          matchesHeading(s.heading, ['top song', 'popular', 'hit song']) &&
          s.items.any((it) => it.type == 'song'),
    );
    final albumsSection = findFirst(
      (s) =>
          matchesHeading(s.heading, ['album', 'discography']) &&
          s.items.any((it) => it.type == 'album'),
    );

    final leftover = allSections.where((s) {
      if (songsSection != null && identical(s, songsSection)) return false;
      if (albumsSection != null && identical(s, albumsSection)) return false;
      return s.items.isNotEmpty;
    }).toList();

    final topRaw = inner['topSongs'] ?? inner['top_songs'] ?? inner['songs'];
    final albumsRaw =
        inner['topAlbums'] ?? inner['top_albums'] ?? inner['albums'];

    final topSongs = songsSection != null
        ? songsSection.items.where((it) => it.type == 'song').toList()
        : listFrom(topRaw);
    final albums = albumsSection != null
        ? albumsSection.items.where((it) => it.type == 'album').toList()
        : listFrom(albumsRaw);

    return ArtistDetail(
      id: (inner['id'] ?? '').toString(),
      name: _decode((inner['name'] ?? inner['title'] ?? '').toString()),
      subtitle: _decodeNullable(inner['subtitle']),
      role: _decodeNullable(inner['role']),
      followers: inner['followers']?.toString(),
      bio: _normalizeArtistBio(inner['bio']),
      songCount: inner['songCount']?.toString(),
      albumCount: inner['albumCount']?.toString(),
      source: inner['source']?.toString(),
      image: ApiImage.listFrom(inner['image']),
      topSongs: topSongs,
      albums: albums,
      sections: leftover,
    );
  }
}

class PodcastShowDetail {
  const PodcastShowDetail({
    required this.id,
    required this.title,
    required this.image,
    required this.episodes,
    this.subtitle,
    this.description,
    this.language,
    this.categories = const [],
    this.url,
    this.itunesId,
    this.episodeCount,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? language;
  final List<String> categories;
  final String? url;
  final int? itunesId;

  final int? episodeCount;
  final List<ApiImage> image;
  final List<FeedItem> episodes;

  String? get artwork {
    if (image.isEmpty) return null;
    final sorted = [...image];
    int score(String q) {
      final m = RegExp(r'(\d+)').firstMatch(q);
      return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
    }

    sorted.sort((a, b) => score(b.quality).compareTo(score(a.quality)));
    return sorted.first.link;
  }

  factory PodcastShowDetail.fromJson(Map<String, dynamic> j) {
    final epRaw = j['episodes'];
    final episodes = epRaw is List
        ? epRaw
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const <FeedItem>[];
    final catsRaw = j['categories'];
    final cats = catsRaw is List
        ? catsRaw.whereType<String>().toList()
        : const <String>[];
    return PodcastShowDetail(
      id: (j['id'] ?? '').toString(),
      title: _decode((j['title'] ?? '').toString()),
      subtitle: _decodeNullable(j['subtitle']),
      description: _decodeNullable(j['description']),
      language: _decodeNullable(j['language']),
      categories: cats,
      url: j['url']?.toString(),
      itunesId: (j['itunesId'] is num) ? (j['itunesId'] as num).toInt() : null,
      episodeCount: (j['episodeCount'] is num)
          ? (j['episodeCount'] as num).toInt()
          : null,
      image: ApiImage.listFrom(j['image']),
      episodes: episodes,
    );
  }
}

class PodcastCategory {
  const PodcastCategory({required this.id, required this.name});
  final int id;
  final String name;

  factory PodcastCategory.fromJson(Map<String, dynamic> j) => PodcastCategory(
    id: (j['id'] is num) ? (j['id'] as num).toInt() : 0,
    name: (j['name'] ?? '').toString(),
  );
}

class SpotifyImportSource {
  const SpotifyImportSource({
    required this.id,
    required this.name,
    required this.trackCount,
    this.description,
    this.owner,
    this.artworkUrl,
    this.url,
  });
  final String id;
  final String name;
  final String? description;
  final String? owner;
  final String? artworkUrl;
  final String? url;
  final int trackCount;

  factory SpotifyImportSource.fromJson(Map<String, dynamic> j) =>
      SpotifyImportSource(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        description: (j['description'] as String?)?.trim().isNotEmpty == true
            ? j['description'] as String
            : null,
        owner: (j['owner'] as String?)?.trim().isNotEmpty == true
            ? j['owner'] as String
            : null,
        artworkUrl: (j['artworkUrl'] as String?)?.trim().isNotEmpty == true
            ? j['artworkUrl'] as String
            : null,
        url: (j['url'] as String?)?.trim().isNotEmpty == true
            ? j['url'] as String
            : null,
        trackCount: (j['trackCount'] is num)
            ? (j['trackCount'] as num).toInt()
            : 0,
      );
}

class SpotifyImportItem {
  const SpotifyImportItem({
    required this.spotifyTitle,
    required this.spotifyArtists,
    required this.matched,
    required this.score,
    this.saavn,
  });

  final String spotifyTitle;
  final List<String> spotifyArtists;

  final FeedItem? saavn;

  final bool matched;

  final double score;

  factory SpotifyImportItem.fromJson(Map<String, dynamic> j) {
    final spotify = (j['spotify'] is Map)
        ? (j['spotify'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final saavnRaw = j['saavn'];
    final artistsRaw = spotify['artists'];
    final artists = artistsRaw is List
        ? artistsRaw.whereType<String>().toList()
        : const <String>[];
    return SpotifyImportItem(
      spotifyTitle: (spotify['name'] ?? '').toString(),
      spotifyArtists: artists,
      saavn: saavnRaw is Map
          ? FeedItem.fromJson(saavnRaw.cast<String, dynamic>())
          : null,
      matched: j['matched'] == true,
      score: (j['score'] is num) ? (j['score'] as num).toDouble() : 0.0,
    );
  }
}

class SpotifyImportSummary {
  const SpotifyImportSummary({
    required this.total,
    required this.matched,
    required this.unmatched,
  });
  final int total;
  final int matched;
  final int unmatched;

  factory SpotifyImportSummary.fromJson(Map<String, dynamic> j) =>
      SpotifyImportSummary(
        total: (j['total'] is num) ? (j['total'] as num).toInt() : 0,
        matched: (j['matched'] is num) ? (j['matched'] as num).toInt() : 0,
        unmatched: (j['unmatched'] is num)
            ? (j['unmatched'] as num).toInt()
            : 0,
      );
}

class SpotifyImportResult {
  const SpotifyImportResult({
    required this.source,
    required this.summary,
    required this.items,
  });
  final SpotifyImportSource source;
  final SpotifyImportSummary summary;
  final List<SpotifyImportItem> items;

  List<FeedItem> get matchedSongs => items
      .where((i) => i.matched && i.saavn != null)
      .map((i) => i.saavn!)
      .toList();

  factory SpotifyImportResult.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['items'];
    final items = itemsRaw is List
        ? itemsRaw
              .whereType<Map>()
              .map((m) => SpotifyImportItem.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const <SpotifyImportItem>[];
    return SpotifyImportResult(
      source: SpotifyImportSource.fromJson(
        (j['source'] is Map)
            ? (j['source'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{},
      ),
      summary: SpotifyImportSummary.fromJson(
        (j['summary'] is Map)
            ? (j['summary'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{},
      ),
      items: items,
    );
  }
}

class AudiobookDetail {
  const AudiobookDetail({
    required this.id,
    required this.title,
    required this.chapters,
    this.subtitle,
    this.author,
    this.cover,
    this.link,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String? author;
  final String? cover;
  final String? link;
  final List<FeedItem> chapters;

  factory AudiobookDetail.fromJson(Map<String, dynamic> j) {
    final chRaw = j['chapters'];
    final chapters = chRaw is List
        ? chRaw
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList()
        : const <FeedItem>[];
    return AudiobookDetail(
      id: (j['id'] ?? '').toString(),
      title: _decode((j['title'] ?? '').toString()),
      subtitle: _decodeNullable(j['subtitle']),
      author: _decodeNullable(j['author']),
      cover: j['cover'] as String?,
      link: j['link'] as String?,
      chapters: chapters,
    );
  }
}

class AudiobookCategory {
  const AudiobookCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });
  final int id;
  final String name;
  final String slug;
  final int count;

  factory AudiobookCategory.fromJson(Map<String, dynamic> j) =>
      AudiobookCategory(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: _decode((j['name'] ?? '').toString()),
        slug: (j['slug'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}
