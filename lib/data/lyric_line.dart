class LyricWord {
  const LyricWord(this.startMs, this.endMs, this.text);

  final int startMs;
  final int endMs;
  final String text;
}

class LyricLine {
  const LyricLine(
    this.timeMs,
    this.text, {
    this.words = const <LyricWord>[],
    this.sungUntilMs,
    this.background,
  });

  final int timeMs;
  final String text;
  final List<LyricWord> words;
  final int? sungUntilMs;
  final LyricLine? background;

  bool get isGap => text.isEmpty;

  bool get isWordSynced => words.isNotEmpty;

  bool get hasKnownEnd => words.isNotEmpty || sungUntilMs != null;

  int get endMs {
    final lead = words.isNotEmpty ? words.last.endMs : sungUntilMs ?? timeMs;
    final backing = background?.endMs;
    return backing != null && backing > lead ? backing : lead;
  }

  LyricLine copyWith({
    String? text,
    List<LyricWord>? words,
    LyricLine? background,
  }) => LyricLine(
    timeMs,
    text ?? this.text,
    words: words ?? this.words,
    sungUntilMs: sungUntilMs,
    background: background ?? this.background,
  );

  (int index, double through)? wordProgress(int positionMs) {
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      if (positionMs < word.startMs) return (index, 0);
      if (positionMs < word.endMs) {
        final span = (word.endMs - word.startMs).clamp(1, 1 << 30);
        return (index, (positionMs - word.startMs) / span);
      }
    }
    return null;
  }

  double revealedChars(int positionMs) {
    if (words.isEmpty) {
      return positionMs >= timeMs ? text.length.toDouble() : 0;
    }
    var offset = 0;
    for (var index = 0; index < words.length; index++) {
      final word = words[index];
      final found = text.indexOf(word.text, offset);
      final start = found >= 0 ? found : offset;
      final end = start + word.text.length;

      if (positionMs < word.startMs) return start.toDouble();
      if (positionMs < word.endMs) {
        final span = (word.endMs - word.startMs).clamp(1, 1 << 30);
        final through = (positionMs - word.startMs) / span;
        return start + through * word.text.length;
      }
      final next = index + 1 < words.length ? words[index + 1] : null;
      if (next != null && positionMs < next.startMs) {
        final gapFound = text.indexOf(next.text, end);
        final gapStart = gapFound >= 0 ? gapFound : end;
        final pause = (next.startMs - word.endMs).clamp(1, 1 << 30);
        final through = (positionMs - word.endMs) / pause;
        return end + through * (gapStart - end);
      }
      offset = end;
    }
    return text.length.toDouble();
  }
}
