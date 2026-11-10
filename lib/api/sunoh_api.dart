import 'package:dio/dio.dart';

import 'dto.dart';

class SunohApi {
  SunohApi(this._dio);
  final Dio _dio;

  Future<List<HomeSection>> fetchHome({String? languages}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/home',
      queryParameters: {
        if (languages != null && languages.isNotEmpty) 'lang': languages,
      },
    );
    final env = ApiEnvelope.from<List<HomeSection>>(
      res.data ?? const {},
      (raw) => (raw is List)
          ? raw
                .whereType<Map>()
                .map((m) => HomeSection.fromJson(m.cast<String, dynamic>()))
                .toList()
          : const <HomeSection>[],
    );
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<AlbumDetail> fetchAlbum(String id, {String? provider}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/album/$id',
      queryParameters: {
        if (provider != null && provider.isNotEmpty) 'provider': provider,
      },
    );
    final env = ApiEnvelope.from<AlbumDetail?>(
      res.data ?? const {},
      (raw) =>
          raw is Map ? AlbumDetail.fromJson(raw.cast<String, dynamic>()) : null,
    );
    if (!env.isSuccess || env.data == null) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data!;
  }

  Future<PlaylistDetail> fetchPlaylist(String id, {String? provider}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/playlist/$id',
      queryParameters: {
        if (provider != null && provider.isNotEmpty) 'provider': provider,
      },
    );
    final env = ApiEnvelope.from<PlaylistDetail?>(
      res.data ?? const {},
      (raw) => raw is Map
          ? PlaylistDetail.fromJson(raw.cast<String, dynamic>())
          : null,
    );
    if (!env.isSuccess || env.data == null) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data!;
  }

  Future<List<HomeSection>> fetchTrendingSearch() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/search',
      queryParameters: const {'query': ''},
    );
    final env = ApiEnvelope.from<List<HomeSection>>(
      res.data ?? const {},
      (raw) => (raw is List)
          ? raw
                .whereType<Map>()
                .map((m) => HomeSection.fromJson(m.cast<String, dynamic>()))
                .toList()
          : const <HomeSection>[],
    );
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<List<HomeSection>> fetchOccasionDetail(
    String slug, {
    String provider = 'gaana',
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/occasions/$slug',
      queryParameters: {if (provider.isNotEmpty) 'provider': provider},
    );
    final env = ApiEnvelope.from<List<HomeSection>>(
      res.data ?? const {},
      (raw) => (raw is List)
          ? raw
                .whereType<Map>()
                .map((m) => HomeSection.fromJson(m.cast<String, dynamic>()))
                .toList()
          : const <HomeSection>[],
    );
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<List<FeedItem>> fetchOccasions({String provider = 'gaana'}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/occasions',
      queryParameters: {if (provider.isNotEmpty) 'provider': provider},
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
            .toList();
      }
      if (raw is Map) {
        final inner = raw['occasions'];
        if (inner is List) {
          return inner
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<String?> fetchRadioSession({
    required String id,
    required String type,
    required String provider,
    String? name,
    String? lang,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/music/radio/session',
        queryParameters: {
          'id': id,
          'type': type,
          'provider': provider,
          if (name != null && name.isNotEmpty) 'name': name,
          if (lang != null && lang.isNotEmpty) 'lang': lang,
        },
      );
      final body = res.data;
      if (body == null) return null;
      final data = body['data'];
      if (data is! Map) return null;
      return (data['stationId'] ?? data['sessionId'])?.toString();
    } on DioException catch (_) {
      return null;
    }
  }

  Future<List<FeedItem>> fetchRecommendations({
    String? songId,
    String? query,
    String? lang,
  }) async {
    final params = <String, dynamic>{
      if (songId != null && songId.isNotEmpty) 'songId': songId,
      if (query != null && query.isNotEmpty) 'q': query,
      if (lang != null && lang.isNotEmpty) 'lang': lang,
    };
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/recommend',
      queryParameters: params,
      options: Options(validateStatus: (_) => true),
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
            .toList();
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<List<FeedItem>> fetchRadioSongs(
    String stationId, {
    int count = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/radio/${Uri.encodeComponent(stationId)}',
      queryParameters: {'count': count, 'next': 1},
      options: Options(validateStatus: (_) => true),
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
            .toList();
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<FeedItem?> fetchSong(String id, {String? provider}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/music/song/$id',
        queryParameters: {
          if (provider != null && provider.isNotEmpty) 'provider': provider,
        },
      );
      final body = res.data;
      if (body == null) return null;
      final raw = body['data'];
      if (raw is! Map) return null;
      final inner = (raw['song'] is Map)
          ? (raw['song'] as Map).cast<String, dynamic>()
          : raw.cast<String, dynamic>();
      return FeedItem.fromJson(inner);
    } on DioException catch (_) {
      return null;
    }
  }

  Future<List<HomeSection>> fetchSearch(
    String query, {
    String? languages,
    String provider = 'unified',
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/search',
      queryParameters: {
        'q': query,
        'type': 'all',
        if (provider.isNotEmpty) 'provider': provider,
        if (languages != null && languages.isNotEmpty) 'lang': languages,
      },
    );
    final env = ApiEnvelope.from<List<HomeSection>>(
      res.data ?? const {},
      (raw) => (raw is List)
          ? raw
                .whereType<Map>()
                .map((m) => HomeSection.fromJson(m.cast<String, dynamic>()))
                .toList()
          : const <HomeSection>[],
    );
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<ArtistDetail> fetchArtist(String id, {String? provider}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/music/artist/$id',
      queryParameters: {
        if (provider != null && provider.isNotEmpty) 'provider': provider,
      },
    );
    final env = ApiEnvelope.from<ArtistDetail?>(
      res.data ?? const {},
      (raw) => raw is Map
          ? ArtistDetail.fromJson(raw.cast<String, dynamic>())
          : null,
    );
    if (!env.isSuccess || env.data == null) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data!;
  }

  Future<List<ApiLanguage>> fetchLanguages() async {
    final res = await _dio.get<Map<String, dynamic>>('/music/languages');
    final env = ApiEnvelope.from<List<ApiLanguage>>(res.data ?? const {}, (
      raw,
    ) {
      if (raw is! List) return const <ApiLanguage>[];
      return raw
          .whereType<Map>()
          .map((m) => ApiLanguage.fromJson(m.cast<String, dynamic>()))
          .toList();
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<List<HomeSection>> fetchPodcastHome({String? country}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/podcasts/home',
      queryParameters: {
        if (country != null && country.isNotEmpty) 'country': country,
      },
    );
    final env = ApiEnvelope.from<List<HomeSection>>(
      res.data ?? const {},
      (raw) => raw is List
          ? raw
                .whereType<Map>()
                .map((m) => HomeSection.fromJson(m.cast<String, dynamic>()))
                .toList()
          : const <HomeSection>[],
    );
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<PodcastShowDetail> fetchPodcastShow(String id, {int max = 30}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/podcasts/${Uri.encodeComponent(id)}',
      queryParameters: {'max': max},
    );
    final env = ApiEnvelope.from<PodcastShowDetail?>(
      res.data ?? const {},
      (raw) => raw is Map
          ? PodcastShowDetail.fromJson(raw.cast<String, dynamic>())
          : null,
    );
    if (!env.isSuccess || env.data == null) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data!;
  }

  Future<List<FeedItem>> fetchPodcastEpisodes(
    String showId, {
    int max = 50,
    int? since,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/podcasts/${Uri.encodeComponent(showId)}/episodes',
      queryParameters: {'max': max, if (since != null) 'since': since},
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<FeedItem?> fetchPodcastEpisode(String guidOrId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/podcasts/episode/${Uri.encodeComponent(guidOrId)}',
    );
    final env = ApiEnvelope.from<FeedItem?>(
      res.data ?? const {},
      (raw) =>
          raw is Map ? FeedItem.fromJson(raw.cast<String, dynamic>()) : null,
    );
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data;
  }

  Future<List<FeedItem>> fetchPodcastSearch(
    String query, {
    int max = 30,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/podcasts/search',
      queryParameters: {'q': query, 'max': max},
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<List<PodcastCategory>> fetchPodcastCategories() async {
    final res = await _dio.get<Map<String, dynamic>>('/podcasts/categories');
    final env = ApiEnvelope.from<List<PodcastCategory>>(res.data ?? const {}, (
      raw,
    ) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => PodcastCategory.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      return const <PodcastCategory>[];
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<List<FeedItem>> fetchPodcastsByCategory(
    String slug, {
    int max = 30,
    String? lang,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/podcasts/by-category/${Uri.encodeComponent(slug)}',
      queryParameters: {
        'max': max,
        if (lang != null && lang.isNotEmpty) 'lang': lang,
      },
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data ?? const [];
  }

  Future<SpotifyImportResult> importSpotifyPlaylist(String spotifyUrl) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/spotify/import',
      queryParameters: {'url': spotifyUrl},
      options: Options(receiveTimeout: const Duration(seconds: 180)),
    );
    final env = ApiEnvelope.from<SpotifyImportResult?>(
      res.data ?? const {},
      (raw) => raw is Map
          ? SpotifyImportResult.fromJson(raw.cast<String, dynamic>())
          : null,
    );
    if (!env.isSuccess || env.data == null) {
      throw SunohApiException(env.message, env.error);
    }
    return env.data!;
  }

  Future<List<HomeSection>> fetchAudiobookHome() async {
    final res = await _dio.get<Map<String, dynamic>>('/audiobooks/home');
    final env = ApiEnvelope.from<List<HomeSection>>(res.data ?? const {}, (
      raw,
    ) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((m) => HomeSection.fromJson(m.cast<String, dynamic>()))
            .toList();
      }
      return const <HomeSection>[];
    });
    if (!env.isSuccess) throw SunohApiException(env.message, env.error);
    return env.data ?? const [];
  }

  Future<List<AudiobookCategory>> fetchAudiobookCategories() async {
    final res = await _dio.get<Map<String, dynamic>>('/audiobooks/categories');
    final env = ApiEnvelope.from<List<AudiobookCategory>>(
      res.data ?? const {},
      (raw) {
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((m) => AudiobookCategory.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
        return const <AudiobookCategory>[];
      },
    );
    if (!env.isSuccess) throw SunohApiException(env.message, env.error);
    return env.data ?? const [];
  }

  Future<List<FeedItem>> fetchAudiobooksByCategory({
    required int categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/audiobooks/by-category',
      queryParameters: {'id': categoryId, 'page': page, 'limit': limit},
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) throw SunohApiException(env.message, env.error);
    return env.data ?? const [];
  }

  Future<List<FeedItem>> fetchAudiobookSearch(String query) async {
    if (query.trim().isEmpty) return const [];
    final res = await _dio.get<Map<String, dynamic>>(
      '/audiobooks/search',
      queryParameters: {'q': query},
    );
    final env = ApiEnvelope.from<List<FeedItem>>(res.data ?? const {}, (raw) {
      if (raw is Map) {
        final list = raw['list'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((m) => FeedItem.fromJson(m.cast<String, dynamic>()))
              .toList();
        }
      }
      return const <FeedItem>[];
    });
    if (!env.isSuccess) throw SunohApiException(env.message, env.error);
    return env.data ?? const [];
  }

  Future<AudiobookDetail?> fetchAudiobookDetail(String slug) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/audiobooks/${Uri.encodeComponent(slug)}',
      );
      final env = ApiEnvelope.from<AudiobookDetail>(res.data ?? const {}, (
        raw,
      ) {
        if (raw is Map) {
          return AudiobookDetail.fromJson(raw.cast<String, dynamic>());
        }
        throw const FormatException('Expected map payload');
      });
      if (!env.isSuccess) return null;
      return env.data;
    } catch (_) {
      return null;
    }
  }
}

class SunohApiException implements Exception {
  SunohApiException(this.message, [this.error]);
  final String message;
  final Object? error;
  @override
  String toString() => 'SunohApiException: $message';
}
