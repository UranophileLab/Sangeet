import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

class LrcLibClient {
  LrcLibClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.lrclibBase,
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {
                'User-Agent': 'sunoh/1.0 (${Env.webBase})',
                'Accept': 'application/json',
              },
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  Future<LyricsLookupResult> fetch({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSec,
  }) async {
    if (trackName.trim().isEmpty || artistName.trim().isEmpty) {
      return LyricsLookupResult.notFound;
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/get',
        queryParameters: {
          'track_name': trackName,
          'artist_name': artistName,
          if (albumName != null && albumName.isNotEmpty)
            'album_name': albumName,
          if (durationSec != null && durationSec > 0) 'duration': durationSec,
        },
      );
      final body = res.data;
      if (body != null) return LyricsLookupResult.fromJson(body);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        debugPrint('[lrclib] exact-get error: $e');
      }
    }
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/search',
        queryParameters: {'track_name': trackName, 'artist_name': artistName},
      );
      final list = res.data;
      if (list == null || list.isEmpty) return LyricsLookupResult.notFound;
      Map<String, dynamic> best = (list.first as Map).cast<String, dynamic>();
      if (durationSec != null && durationSec > 0) {
        int bestDelta = (durationSec - _intOr(best['duration'], 0)).abs();
        for (final raw in list) {
          if (raw is! Map) continue;
          final m = raw.cast<String, dynamic>();
          final delta = (durationSec - _intOr(m['duration'], 0)).abs();
          if (delta < bestDelta) {
            best = m;
            bestDelta = delta;
          }
        }
      }
      return LyricsLookupResult.fromJson(best);
    } on DioException catch (e) {
      debugPrint('[lrclib] search error: $e');
      return LyricsLookupResult.notFound;
    }
  }
}

int _intOr(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class LyricsLookupResult {
  const LyricsLookupResult({
    required this.found,
    required this.instrumental,
    this.plainLyrics,
    this.syncedLyrics,
  });

  static const LyricsLookupResult notFound = LyricsLookupResult(
    found: false,
    instrumental: false,
  );

  final bool found;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  bool get hasSynced => syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;
  bool get hasPlain => plainLyrics != null && plainLyrics!.trim().isNotEmpty;

  factory LyricsLookupResult.fromJson(Map<String, dynamic> j) {
    return LyricsLookupResult(
      found: true,
      instrumental: j['instrumental'] == true,
      plainLyrics: (j['plainLyrics'] as String?)?.trim(),
      syncedLyrics: (j['syncedLyrics'] as String?)?.trim(),
    );
  }
}
