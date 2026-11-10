import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../audio/url_refresh.dart';
import 'dto.dart';

enum LosslessLookup {
  searching,
  found,
  unavailable,
}

class LosslessStatus {
  const LosslessStatus(this.songId, this.state);
  final String songId;
  final LosslessLookup state;
}

class LosslessStream {
  const LosslessStream({
    required this.url,
    required this.expiresAt,
    this.bitDepth,
    this.sampleRate,
    this.sizeBytes,
  });

  final String url;
  final DateTime expiresAt;
  final int? bitDepth;
  final int? sampleRate;
  final int? sizeBytes;

  String? get label {
    if (bitDepth == null || sampleRate == null) return null;
    final khz = (sampleRate! / 1000).toStringAsFixed(1).replaceAll('.0', '');
    return '$bitDepth-bit / $khz kHz';
  }
}

class LosslessApi {
  LosslessApi(this._dio);

  final Dio _dio;

  final Set<String> _unavailable = <String>{};

  final Map<String, LosslessStream> _resolved = <String, LosslessStream>{};

  final ValueNotifier<LosslessStatus?> status = ValueNotifier<LosslessStatus?>(
    null,
  );

  void _publish(String songId, LosslessLookup state) =>
      status.value = LosslessStatus(songId, state);

  static const Duration _expiryMargin = Duration(minutes: 2);

  bool _usable(LosslessStream s) =>
      DateTime.now().isBefore(s.expiresAt.subtract(_expiryMargin));

  static const Duration _budget = Duration(seconds: 3);

  final Map<String, Future<LosslessStream?>> _inFlight =
      <String, Future<LosslessStream?>>{};

  String? labelFor(String songId) {
    final s = _resolved[songId];
    return s != null && _usable(s) ? s.label : null;
  }

  void reset() {
    _unavailable.clear();
    _resolved.clear();
  }

  void warm(FeedItem song, {String quality = 'auto'}) {
    if (_unavailable.contains(song.id)) return;
    final known = _resolved[song.id];
    if (known != null && _usable(known)) return;
    if (_inFlight.containsKey(song.id)) return;
    _inFlight[song.id] = _fetch(song, quality);
  }

  bool isLooking(String songId) => _inFlight.containsKey(songId);

  Future<LosslessStream?> resolve(
    FeedItem song, {
    String quality = 'auto',
  }) async {
    if (_unavailable.contains(song.id)) {
      _publish(song.id, LosslessLookup.unavailable);
      return null;
    }

    final known = _resolved[song.id];
    if (known != null) {
      if (_usable(known)) {
        _publish(song.id, LosslessLookup.found);
        return known;
      }
      _resolved.remove(song.id);
    }

    _publish(song.id, LosslessLookup.searching);

    final request = _inFlight[song.id] ??= _fetch(song, quality);
    try {
      return await request.timeout(_budget);
    } on TimeoutException {
      debugPrint('[audio] lossless still looking for ${song.id}');
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<LosslessStream?> _fetch(FeedItem song, String quality) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/lossless/stream-url',
        data: <String, dynamic>{
          'quality': quality,
          'song': <String, dynamic>{
            'id': song.id,
            'title': song.title,
            'subtitle': song.subtitle,
            'duration': song.duration,
            'source': song.source,
          },
        },
      );

      final data = res.data?['data'];
      final url = data is Map ? data['url'] as String? : null;
      if (url == null || url.isEmpty) {
        _unavailable.add(song.id);
        _publish(song.id, LosslessLookup.unavailable);
        return null;
      }

      final stream = LosslessStream(
        url: url,
        expiresAt:
            UrlRefreshScheduler.expiryFromNumber(data['expiresAt']) ??
            DateTime.now().add(const Duration(minutes: 30)),
        bitDepth: (data['bitDepth'] as num?)?.toInt(),
        sampleRate: (data['sampleRate'] as num?)?.toInt(),
        sizeBytes: (data['sizeBytes'] as num?)?.toInt(),
      );
      _resolved[song.id] = stream;
      _publish(song.id, LosslessLookup.found);
      return stream;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _unavailable.add(song.id);
        _publish(song.id, LosslessLookup.unavailable);
      } else {
        debugPrint(
          '[audio] lossless lookup failed for ${song.id}: ${e.type.name}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('[audio] lossless lookup error for ${song.id}: $e');
      return null;
    } finally {
      _inFlight.remove(song.id);
    }
  }
}
