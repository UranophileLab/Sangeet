import 'package:xml/xml.dart';

import '../../data/lyric_line.dart';
import 'lyric_gaps.dart';

const Set<String> _skippedRoles = {'x-translation', 'x-roman'};

const String _backgroundRole = 'x-bg';

List<LyricLine> parseTtml(String ttml) {
  try {
    final document = XmlDocument.parse(ttml);
    final lines = <LyricLine>[];
    for (final paragraph in document.findAllElements('p')) {
      final line = _lineFrom(paragraph);
      if (line != null) lines.add(line);
    }
    lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return withInstrumentalGaps(lines);
  } on Object {
    return const <LyricLine>[];
  }
}

LyricLine? _lineFrom(XmlElement paragraph) {
  final pieces = <_Piece>[];
  final backingPieces = <_Piece>[];
  _collect(paragraph, pieces, backingPieces);

  final words = _mergeIntoWords(pieces);
  final backingWords = _mergeIntoWords(backingPieces);
  final backing = backingWords.isEmpty
      ? null
      : LyricLine(
          backingWords.first.startMs,
          backingWords.map((w) => w.text).join(' '),
          words: backingWords,
        );

  if (words.isEmpty) {
    final text = paragraph.innerText.trim();
    final begin = ttmlTime(paragraph.getAttribute('begin'));
    if (begin == null || text.isEmpty) return null;
    final end = ttmlTime(paragraph.getAttribute('end'));
    return LyricLine(
      begin,
      text,
      sungUntilMs: end != null && end > begin ? end : null,
    );
  }

  final begin =
      ttmlTime(paragraph.getAttribute('begin')) ?? words.first.startMs;
  return LyricLine(
    begin < words.first.startMs ? begin : words.first.startMs,
    words.map((w) => w.text).join(' '),
    words: words,
    background: backing,
  );
}

void _collect(XmlNode node, List<_Piece> out, List<_Piece> backing) {
  for (final child in node.children) {
    if (child is XmlElement) {
      final role = child.getAttribute('ttm:role') ?? '';
      if (_skippedRoles.contains(role)) continue;
      final sink = role == _backgroundRole ? backing : out;
      final begin = ttmlTime(child.getAttribute('begin'));
      final end = ttmlTime(child.getAttribute('end'));
      if (begin != null && end != null && !_hasTimedChild(child)) {
        sink.add(_Piece(child.innerText, begin, end));
      } else {
        _collect(child, sink, backing);
      }
    } else if (child is XmlText) {
      if (child.value.isNotEmpty) out.add(_Piece(child.value, null, null));
    }
  }
}

bool _hasTimedChild(XmlElement element) {
  for (final child in element.children.whereType<XmlElement>()) {
    if ((child.getAttribute('begin') ?? '').isNotEmpty) return true;
    if (_hasTimedChild(child)) return true;
  }
  return false;
}

List<LyricWord> _mergeIntoWords(List<_Piece> pieces) {
  final words = <LyricWord>[];
  final current = StringBuffer();
  var start = 0;
  var end = 0;
  var timed = false;

  void flush() {
    final text = current.toString().trim();
    current.clear();
    if (text.isNotEmpty && timed) words.add(LyricWord(start, end, text));
    timed = false;
  }

  for (final piece in pieces) {
    if (piece.start == null || piece.end == null) {
      if (piece.text.trim().isEmpty) {
        flush();
      } else if (timed) {
        current.write(piece.text);
      }
      continue;
    }
    if (piece.text.trim().isEmpty) continue;
    if (_startsWithSpace(piece.text)) flush();
    if (current.isEmpty) start = piece.start!;
    current.write(piece.text.trim());
    end = piece.end!;
    timed = true;
    if (_endsWithSpace(piece.text)) flush();
  }
  flush();
  return words;
}

bool _startsWithSpace(String s) => s.isNotEmpty && s[0].trim().isEmpty;
bool _endsWithSpace(String s) => s.isNotEmpty && s[s.length - 1].trim().isEmpty;

int? ttmlTime(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.endsWith('ms')) {
    return double.tryParse(raw.substring(0, raw.length - 2))?.round();
  }
  final stripped = raw.endsWith('s') ? raw.substring(0, raw.length - 1) : raw;
  final parts = stripped.split(':');
  final numbers = <double>[];
  for (final part in parts) {
    final n = double.tryParse(part);
    if (n == null) return null;
    numbers.add(n);
  }
  final seconds = switch (numbers.length) {
    1 => numbers[0],
    2 => numbers[0] * 60 + numbers[1],
    3 => numbers[0] * 3600 + numbers[1] * 60 + numbers[2],
    _ => null,
  };
  return seconds == null ? null : (seconds * 1000).round();
}

class _Piece {
  const _Piece(this.text, this.start, this.end);
  final String text;
  final int? start;
  final int? end;
}
