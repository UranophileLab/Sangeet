import '../../data/lyric_line.dart';
import 'lyric_gaps.dart';

final RegExp _stamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
final RegExp _wordStamp = RegExp(r'<(\d{1,3}):(\d{2})[.:](\d{2,3})>');

List<LyricLine> parseLrc(String raw) {
  final all = <LyricLine>[];
  for (final rawLine in raw.split('\n')) {
    final line = rawLine.replaceAll('\r', '');
    final matches = _stamp.allMatches(line).toList();
    if (matches.isEmpty) continue;

    final body = line.substring(matches.last.end);
    final text = body.replaceAll(_wordStamp, '').trim();
    final words = _parseWordRuns(body);

    for (final m in matches) {
      all.add(
        LyricLine(
          _msOf(m.group(1)!, m.group(2)!, m.group(3)),
          text,
          words: words,
        ),
      );
    }
  }
  all.sort((a, b) => a.timeMs.compareTo(b.timeMs));

  final kept = <LyricLine>[];
  for (var i = 0; i < all.length; i++) {
    final line = all[i];
    if (!line.isGap) {
      kept.add(line);
      continue;
    }
    if (i + 1 >= all.length) {
      kept.add(line);
      continue;
    }
    if (all[i + 1].timeMs - line.timeMs >= kMinGapMs) kept.add(line);
  }

  if (kept.isEmpty) return kept;
  final first = kept.first;
  if (!first.isGap && first.timeMs >= kMinGapMs) {
    return [const LyricLine(0, ''), ...kept];
  }
  return kept;
}

List<LyricWord> _parseWordRuns(String body) {
  final marks = _wordStamp.allMatches(body).toList();
  if (marks.isEmpty) return const <LyricWord>[];

  final starts = <int>[];
  final texts = <String>[];
  for (var i = 0; i < marks.length; i++) {
    final until = i + 1 < marks.length ? marks[i + 1].start : body.length;
    starts.add(
      _msOf(marks[i].group(1)!, marks[i].group(2)!, marks[i].group(3)),
    );
    texts.add(body.substring(marks[i].end, until));
  }

  final words = <LyricWord>[];
  for (var i = 0; i < starts.length; i++) {
    if (texts[i].trim().isEmpty) continue;
    final end = i + 1 < starts.length ? starts[i + 1] : starts[i];
    words.add(
      LyricWord(starts[i], end < starts[i] ? starts[i] : end, texts[i].trim()),
    );
  }
  return words;
}

int _msOf(String minutes, String seconds, String? fraction) {
  final fractionMs = switch (fraction?.length) {
    1 => int.parse(fraction!) * 100,
    2 => int.parse(fraction!) * 10,
    3 => int.parse(fraction!),
    _ => 0,
  };
  return int.parse(minutes) * 60000 + int.parse(seconds) * 1000 + fractionMs;
}

List<LyricLine> plainLyricsAsLines(String raw, {int totalSec = 180}) {
  final lines = raw.split('\n').map((l) => l.trim()).toList();
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty) return const [];
  final spacing = (totalSec / lines.length).clamp(2.0, 8.0);
  return [
    for (var i = 0; i < lines.length; i++)
      LyricLine((i * spacing * 1000).round(), lines[i]),
  ];
}
