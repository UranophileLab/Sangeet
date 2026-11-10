import 'dart:async';
import 'dart:convert';

import '../../config/env.dart';
import '../../data/lyric_line.dart';
import 'lyric_gaps.dart';
import 'lyrics_http.dart';

String? _lastGood;

Future<List<LyricLine>?> fetchLyricsPlus({
  required String title,
  required String artist,
  required int durationMs,
  String? album,
}) async {
  final mirrors = Env.lyricsPlusMirrors
      .split(',')
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty)
      .toList();
  if (mirrors.isEmpty) return null;

  final good = _lastGood;
  final hosts = good != null && mirrors.contains(good)
      ? [good, ...mirrors.where((m) => m != good)]
      : mirrors;

  final winner = Completer<List<LyricLine>?>();
  var outstanding = hosts.length;
  for (final host in hosts) {
    unawaited(
      _fetch(host, title, artist, durationMs, album).then((lines) {
        if (winner.isCompleted) return;
        if (lines != null && lines.isNotEmpty) {
          _lastGood = host;
          winner.complete(lines);
          return;
        }
        if (--outstanding == 0) winner.complete(null);
      }),
    );
  }
  return winner.future;
}

Future<List<LyricLine>?> _fetch(
  String host,
  String title,
  String artist,
  int durationMs,
  String? album,
) async {
  final seconds = durationMs ~/ 1000;
  final url = Uri.parse('$host/v2/lyrics/get').replace(
    queryParameters: {
      'title': title,
      'artist': artist,
      if (seconds > 0) 'duration': '$seconds',
      if (album != null && album.isNotEmpty) 'album': album,
    },
  );

  final body = await lyricsGet(url.toString());
  if (body == null) return null;
  try {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final raw = json['lyrics'];
    if (raw is! List) return null;
    final lines = _parse(raw);
    return lines.isEmpty ? null : lines;
  } on Object {
    return null;
  }
}

List<LyricLine> _parse(List<dynamic> rows) {
  final out = <LyricLine>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final start = (row['time'] as num?)?.toInt();
    if (start == null) continue;

    final words = _mergeSyllables(row['syllabus']);
    if (words.isNotEmpty) {
      final first = words.first.startMs;
      out.add(
        LyricLine(
          start < first ? start : first,
          words.map((w) => w.text).join(' '),
          words: words,
        ),
      );
      continue;
    }
    final text = (row['text'] as String?)?.trim();
    if (text == null || text.isEmpty) continue;
    final duration = (row['duration'] as num?)?.toInt();
    out.add(
      LyricLine(
        start,
        text,
        sungUntilMs: duration != null && duration > 0 ? start + duration : null,
      ),
    );
  }
  out.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return withInstrumentalGaps(out);
}

List<LyricWord> _mergeSyllables(Object? raw) {
  if (raw is! List) return const <LyricWord>[];
  final words = <LyricWord>[];
  final current = StringBuffer();
  var start = 0;
  var end = 0;

  for (final entry in raw) {
    if (entry is! Map) continue;
    final text = entry['text'] as String?;
    if (text == null || text.trim().isEmpty) continue;
    final time = (entry['time'] as num?)?.toInt();
    if (time == null) continue;

    if (current.isEmpty) start = time;
    current.write(text.trim());
    end = time + ((entry['duration'] as num?)?.toInt() ?? 0);
    if (text[text.length - 1].trim().isEmpty) {
      words.add(LyricWord(start, end, current.toString()));
      current.clear();
    }
  }
  if (current.isNotEmpty) words.add(LyricWord(start, end, current.toString()));
  return words;
}
