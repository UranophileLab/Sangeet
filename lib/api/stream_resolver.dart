import 'package:dio/dio.dart';

import '../audio/url_refresh.dart';
import 'dto.dart';
import 'local_media_channel.dart';
import 'lossless_api.dart';
import 'ytmusic_channel.dart';

enum StreamQuality { auto, high, data, lossless }

abstract interface class LocalSourceProvider {
  Future<String?> localUrlFor(String songId);
}

class StreamResolver {
  StreamResolver(this._dio);
  final Dio _dio;

  StreamQuality quality = StreamQuality.auto;

  LocalSourceProvider? localSource;

  LosslessApi? lossless;

  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  static const _kExpirySafetyBuffer = Duration(seconds: 60);

  void invalidate(String songId) => _cache.remove(songId);

  String _qualityParam() => switch (quality) {
    StreamQuality.high => 'high',
    StreamQuality.data => 'data',
    StreamQuality.auto => 'auto',
    StreamQuality.lossless => 'high',
  };

  void warmLossless(FeedItem song) {
    if (quality != StreamQuality.lossless) return;
    lossless?.warm(song, quality: _qualityParam());
  }

  void setQualityFromString(String value) {
    final previous = quality;
    quality = switch (value) {
      'high' => StreamQuality.high,
      'data' => StreamQuality.data,
      'lossless' => StreamQuality.lossless,
      _ => StreamQuality.auto,
    };
    if (quality != previous) _cache.clear();
  }

  Future<ResolvedStream> resolve(
    FeedItem song, {
    bool forceRefresh = false,
    bool network = false,
  }) async {
    final local = localSource;
    if (local != null && !network) {
      try {
        final url = await local.localUrlFor(song.id);
        if (url != null && url.isNotEmpty) {
          return ResolvedStream(url);
        }
      } catch (_) {
      }
    }

    if (song.source == kLocalSource) {
      final path = song.url ?? '';
      if (path.isEmpty) {
        throw StreamResolveException(
          'On-device track "${song.title}" has no file path.',
        );
      }
      return ResolvedStream(path);
    }

    if (forceRefresh) {
      _cache.remove(song.id);
    } else {
      final cached = _cache[song.id];
      if (cached != null && !_isStale(cached)) return cached.stream;
      if (cached != null) _cache.remove(song.id);
    }

    final ll = lossless;
    if (quality == StreamQuality.lossless && ll != null) {
      final hit = await ll.resolve(song, quality: _qualityParam());
      if (hit != null) {
        return _store(song.id, ResolvedStream(hit.url), expiry: hit.expiresAt);
      }
    }

    if (song.source == 'youtube') {
      final yt = await YtMusicChannel.instance.resolve(
        song.id,
        quality: _qualityParam(),
      );
      if (yt == null) {
        throw StreamResolveException(
          'No playable stream for "${song.title}" (${song.id}).',
        );
      }
      return ResolvedStream(yt.url, httpHeaders: yt.headers);
    }

    if (!forceRefresh) {
      final embedded = _pick(song.mediaUrls);
      if (embedded != null) {
        return _store(song.id, ResolvedStream(embedded));
      }
    }

    final provider = song.source;

    if (provider == 'podcastindex') {
      try {
        final res = await _dio.get<Map<String, dynamic>>(
          '/podcasts/episode/${Uri.encodeComponent(song.id)}',
        );
        final dataRaw = res.data?['data'];
        if (dataRaw is Map) {
          final parsed = FeedItem.fromJson(dataRaw.cast<String, dynamic>());
          final url = _pick(parsed.mediaUrls);
          if (url != null) {
            return _store(song.id, ResolvedStream(url, enriched: parsed));
          }
        }
      } on DioException catch (_) {
      }
      throw StreamResolveException(
        'No playable stream variants for "${song.title}" (${song.id}).',
      );
    }

    final query = <String, dynamic>{
      if (provider != null && provider.isNotEmpty) 'provider': provider,
    };

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/music/song/${song.id}',
        queryParameters: query,
      );
      final parsed = _enrichFromSongResponse(res.data);
      final url = _pick(parsed?.mediaUrls ?? const []);
      if (url != null) {
        return _store(song.id, ResolvedStream(url, enriched: parsed));
      }
    } on DioException catch (_) {
    }

    if (provider == 'gaana') {
      final res = await _dio.get<Map<String, dynamic>>(
        '/music/song/${song.id}/stream',
        queryParameters: query,
      );
      final env = ApiEnvelope.from<List<ApiImage>>(
        res.data ?? const {},
        ApiImage.listFrom,
      );
      if (env.isSuccess) {
        final picked = _pick(env.data ?? const []);
        if (picked != null) {
          return _store(song.id, ResolvedStream(picked));
        }
      }
    }

    throw StreamResolveException(
      'No playable stream variants for "${song.title}" (${song.id}).',
    );
  }

  ResolvedStream _store(
    String songId,
    ResolvedStream stream, {
    DateTime? expiry,
  }) {
    _cache[songId] = _CacheEntry(
      stream: stream,
      expiry: expiry ?? UrlRefreshScheduler.parseExpiry(stream.url),
    );
    return stream;
  }

  bool _isStale(_CacheEntry e) {
    final expiry = e.expiry;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry.subtract(_kExpirySafetyBuffer));
  }

  FeedItem? _enrichFromSongResponse(Map<String, dynamic>? body) {
    if (body == null) return null;
    final dataRaw = body['data'];
    if (dataRaw is! Map) return null;
    final data = dataRaw.cast<String, dynamic>();
    final inner = (data['song'] is Map)
        ? (data['song'] as Map).cast<String, dynamic>()
        : data;
    if (inner.isEmpty) return null;
    return FeedItem.fromJson(inner);
  }

  String? _pick(List<ApiImage> variants) {
    if (variants.isEmpty) return null;

    final sorted = [...variants]
      ..sort((a, b) => _score(b.quality).compareTo(_score(a.quality)));

    return switch (quality) {
      StreamQuality.data => sorted.last.link,
      StreamQuality.auto ||
      StreamQuality.high ||
      StreamQuality.lossless => sorted.first.link,
    };
  }

  static int _score(String q) {
    final qq = q.toLowerCase();
    switch (qq) {
      case 'high':
        return 320;
      case 'medium':
        return 160;
      case 'low':
        return 96;
    }
    final m = RegExp(r'(\d+)').firstMatch(qq);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }
}

class StreamResolveException implements Exception {
  StreamResolveException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => 'StreamResolveException: $message';
}

class ResolvedStream {
  ResolvedStream(this.url, {this.enriched, this.httpHeaders});
  final String url;
  final FeedItem? enriched;

  final Map<String, String>? httpHeaders;
}

class _CacheEntry {
  _CacheEntry({required this.stream, required this.expiry});
  final ResolvedStream stream;
  final DateTime? expiry;
}
