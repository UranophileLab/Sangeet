import '../../data/lyric_line.dart';
import 'lyric_gaps.dart';

final RegExp _line = RegExp(r'^\[(\d{1,3}):(\d{2})[.:](\d{2,3})\](.*)$');
final RegExp _word = RegExp(r'<(\d{1,3}):(\d{2})[.:](\d{2,3})>([^<]*)');

const int _tailMs = 800;

List<LyricLine> parseEnhancedLrc(String lrc) {
  final rows = <_Row>[];
  for (final raw in lrc.split('\n')) {
    final match = _line.firstMatch(raw.trim());
    if (match == null) continue;
    rows.add(
      _Row(
        _stamp(match.group(1)!, match.group(2)!, match.group(3)!),
        _word.allMatches(match.group(4)!).toList(),
        match.group(4)!.trim(),
      ),
    );
  }
  rows.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  if (!rows.any((r) => r.words.isNotEmpty)) return const <LyricLine>[];

  final out = <LyricLine>[];
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    if (row.words.isEmpty) {
      final text = decodeEntities(row.plain);
      if (text.isNotEmpty) out.add(LyricLine(row.timeMs, text));
      continue;
    }
    final lineEnd = index + 1 < rows.length
        ? rows[index + 1].timeMs
        : _stampOf(row.words.last) + _tailMs;

    final words = <LyricWord>[];
    for (var i = 0; i < row.words.length; i++) {
      final text = decodeEntities(row.words[i].group(4)!).trim();
      if (text.isEmpty) continue;
      final start = _stampOf(row.words[i]);
      final end = i + 1 < row.words.length
          ? _stampOf(row.words[i + 1])
          : lineEnd;
      words.add(LyricWord(start, end < start ? start : end, text));
    }
    if (words.isEmpty) continue;
    final first = words.first.startMs;
    out.add(
      LyricLine(
        row.timeMs < first ? row.timeMs : first,
        words.map((w) => w.text).join(' '),
        words: words,
      ),
    );
  }
  return withInstrumentalGaps(out);
}

class _Row {
  const _Row(this.timeMs, this.words, this.plain);
  final int timeMs;
  final List<RegExpMatch> words;
  final String plain;
}

int _stampOf(RegExpMatch match) =>
    _stamp(match.group(1)!, match.group(2)!, match.group(3)!);

int _stamp(String minutes, String seconds, String fraction) {
  final fractionMs = fraction.length == 3
      ? int.parse(fraction)
      : int.parse(fraction) * 10;
  return int.parse(minutes) * 60000 + int.parse(seconds) * 1000 + fractionMs;
}

String decodeEntities(String text) {
  if (!text.contains('&')) return text;
  return text
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
