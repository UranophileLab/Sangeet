import '../../data/lyric_line.dart';

List<LyricLine> withBackgroundVocals(List<LyricLine> lines) =>
    lines.map(_splitTrailingBracket).toList();

LyricLine _splitTrailingBracket(LyricLine line) {
  if (line.background != null || line.isGap) return line;

  final open = _bracketStart(line.text);
  if (open == null) return line;
  final lead = line.text.substring(0, open).trimRight();
  final backing = line.text.substring(open).trim();
  if (lead.isEmpty) return line;
  if (!backing.contains(RegExp(r'[\p{L}\p{N}]', unicode: true))) return line;

  if (line.words.isEmpty) {
    return line.copyWith(
      text: lead,
      background: LyricLine(
        line.timeMs,
        backing,
        sungUntilMs: line.sungUntilMs,
      ),
    );
  }

  final split = _indexOfWordStartingAt(line.words, open);
  if (split == null || split <= 0) return line;

  final backingWords = line.words.sublist(split);
  return line.copyWith(
    text: lead,
    words: line.words.sublist(0, split),
    background: LyricLine(
      backingWords.first.startMs,
      backing,
      words: backingWords,
    ),
  );
}

int? _indexOfWordStartingAt(List<LyricWord> words, int offset) {
  var at = 0;
  for (var index = 0; index < words.length; index++) {
    if (at == offset) return index;
    if (at > offset) return null;
    at += words[index].text.length + 1;
  }
  return null;
}

int? _bracketStart(String text) {
  if (!text.endsWith(')')) return null;
  var depth = 0;
  for (var index = text.length - 1; index >= 0; index--) {
    final char = text[index];
    if (char == ')') {
      depth++;
    } else if (char == '(') {
      depth--;
      if (depth == 0) return index > 0 ? index : null;
    }
  }
  return null;
}
