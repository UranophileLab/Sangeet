import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../config/env.dart';

class SkipSegment {
  const SkipSegment({
    required this.start,
    required this.end,
    required this.category,
    required this.uuid,
  });

  final Duration start;
  final Duration end;
  final String category;

  final String uuid;

  Duration get length => end - start;

  @override
  String toString() => '$category ${start.inSeconds}s->${end.inSeconds}s';
}

const kDefaultSponsorBlockCategories = <String>{
  'sponsor',
  'selfpromo',
  'interaction',
  'intro',
  'outro',
  'music_offtopic',
};

class SponsorBlockClient {
  SponsorBlockClient(this._dio);
  final Dio _dio;

  static const _kBase = Env.sponsorBlockBase;

  Future<List<SkipSegment>> segmentsFor(
    String videoId, {
    Set<String> categories = kDefaultSponsorBlockCategories,
  }) async {
    if (videoId.isEmpty || categories.isEmpty) return const [];
    final prefix = sha256
        .convert(utf8.encode(videoId))
        .toString()
        .substring(0, 4);
    try {
      final res = await _dio.get<List<dynamic>>(
        '$_kBase/$prefix',
        queryParameters: {'categories': jsonEncode(categories.toList())},
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
          headers: const {'Accept': 'application/json'},
        ),
      );
      final body = res.data;
      if (body == null) return const [];

      for (final entry in body) {
        if (entry is! Map) continue;
        if (entry['videoID'] != videoId) continue;
        return _parseSegments(entry['segments'], categories);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<SkipSegment> _parseSegments(Object? raw, Set<String> categories) {
    if (raw is! List) return const [];
    final out = <SkipSegment>[];
    for (final s in raw) {
      if (s is! Map) continue;

      if ((s['actionType'] ?? 'skip') != 'skip') continue;

      final votes = (s['votes'] as num?)?.toInt() ?? 0;
      if (votes < 0) continue;

      final category = (s['category'] ?? '').toString();
      if (!categories.contains(category)) continue;

      final bounds = s['segment'];
      if (bounds is! List || bounds.length < 2) continue;
      final startSec = (bounds[0] as num?)?.toDouble();
      final endSec = (bounds[1] as num?)?.toDouble();
      if (startSec == null || endSec == null || endSec <= startSec) continue;

      out.add(
        SkipSegment(
          start: Duration(milliseconds: (startSec * 1000).round()),
          end: Duration(milliseconds: (endSec * 1000).round()),
          category: category,
          uuid: (s['UUID'] ?? '').toString(),
        ),
      );
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }
}
