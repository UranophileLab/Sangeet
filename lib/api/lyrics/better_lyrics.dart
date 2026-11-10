import 'dart:convert';

import '../../config/env.dart';
import '../../data/lyric_line.dart';
import 'lyrics_http.dart';
import 'ttml_lyrics.dart';

Future<List<LyricLine>?> fetchBetterLyrics({
  required String title,
  required String artist,
  required int durationMs,
  String? album,
}) async {
  if (Env.betterLyricsBase.isEmpty) return null;
  final seconds = durationMs ~/ 1000;
  final url = Uri.parse(Env.betterLyricsBase).replace(
    queryParameters: {
      's': title,
      'a': artist,
      if (seconds > 0) 'd': '$seconds',
      if (album != null && album.isNotEmpty) 'al': album,
    },
  );

  final body = await lyricsGet(url.toString());
  if (body == null) return null;
  final ttml = _ttmlOf(body);
  if (ttml == null || ttml.isEmpty) return null;

  final lines = parseTtml(ttml);
  return lines.isEmpty ? null : lines;
}

String? _ttmlOf(String body) {
  try {
    final json = jsonDecode(body);
    return json is Map ? json['ttml'] as String? : null;
  } on Object {
    return null;
  }
}
