import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/lyric_line.dart';
import 'background_vocals.dart';
import 'better_lyrics.dart';
import 'lrclib_source.dart';
import 'lyrics_plus.dart';
import 'lyrics_source.dart';
import 'musixmatch.dart';
import 'paxsenix.dart';
import 'simpmusic_lyrics.dart';

class LyricsHit {
  const LyricsHit(this.source, this.lines);
  final LyricsSource source;
  final List<LyricLine> lines;
}

Future<LyricsHit?> fetchLyrics({
  required String title,
  required String artist,
  required int durationMs,
  String videoId = '',
  String? album,
  Set<LyricsSource> sources = const {...LyricsSource.values},
  bool prioritiseWordSync = false,
}) async {
  final order = LyricsSource.values.where(sources.contains).toList();
  if (order.isEmpty || title.trim().isEmpty) return null;

  final racing = <LyricsSource, Future<List<LyricLine>?>>{
    for (final source in order)
      source: _fetch(source, title, artist, durationMs, videoId, album)
          .catchError((Object e) {
            debugPrint('[lyrics] ${source.label} failed: $e');
            return null;
          }),
  };

  LyricsHit? lineSynced;
  for (final source in order) {
    final lines = await racing[source];
    if (lines == null || lines.isEmpty) continue;

    if (lines.any((l) => l.isWordSynced)) return _hit(source, lines);
    if (!prioritiseWordSync) return _hit(source, lines);
    lineSynced ??= _hit(source, lines);
  }
  return lineSynced;
}

Future<List<LyricLine>?> _fetch(
  LyricsSource source,
  String title,
  String artist,
  int durationMs,
  String videoId,
  String? album,
) => switch (source) {
  LyricsSource.betterLyrics => fetchBetterLyrics(
    title: title,
    artist: artist,
    durationMs: durationMs,
    album: album,
  ),
  LyricsSource.lyricsPlus => fetchLyricsPlus(
    title: title,
    artist: artist,
    durationMs: durationMs,
    album: album,
  ),
  LyricsSource.paxSenix => fetchPaxSenix(
    title: title,
    artist: artist,
    durationMs: durationMs,
    album: album,
  ),
  LyricsSource.simpMusic => fetchSimpMusicLyrics(
    videoId: videoId,
    durationMs: durationMs,
  ),
  LyricsSource.lrcLib => fetchLrcLib(
    title: title,
    artist: artist,
    durationMs: durationMs,
    album: album,
  ),
  LyricsSource.musixmatch => fetchMusixmatch(
    title: title,
    artist: artist,
    durationMs: durationMs,
  ),
};

LyricsHit _hit(LyricsSource source, List<LyricLine> lines) {
  debugPrint('[lyrics] ${source.label} answered with ${lines.length} lines');
  return LyricsHit(source, withBackgroundVocals(lines));
}
