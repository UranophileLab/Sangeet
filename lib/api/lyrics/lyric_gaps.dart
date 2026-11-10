import '../../data/lyric_line.dart';

const int kMinGapMs = 4000;

List<LyricLine> withInstrumentalGaps(List<LyricLine> lines) {
  if (lines.isEmpty) return lines;
  final out = <LyricLine>[];
  if (lines.first.timeMs >= kMinGapMs) out.add(const LyricLine(0, ''));

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    out.add(line);
    if (index + 1 >= lines.length) continue;
    if (!line.hasKnownEnd) continue;

    final silence = lines[index + 1].timeMs - line.endMs;
    if (silence >= kMinGapMs && line.endMs > line.timeMs) {
      out.add(LyricLine(line.endMs, ''));
    }
  }
  return out;
}
