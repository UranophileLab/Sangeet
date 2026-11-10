import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../config/env.dart';
import '../../data/lyric_line.dart';
import 'lrc_parser.dart';
import 'lyrics_http.dart';

const String _appId = 'web-desktop-app-v1.0';

String? _cachedToken;
Future<String?>? _tokenInFlight;

Future<List<LyricLine>?> fetchMusixmatch({
  required String title,
  required String artist,
  required int durationMs,
}) async {
  if (Env.musixmatchBase.isEmpty || Env.musixmatchSecret.isEmpty) return null;

  final tracks = await _searchTrack(title, artist);
  if (tracks == null || tracks.isEmpty) return null;

  final seconds = durationMs ~/ 1000;
  Map<String, dynamic>? best;
  var bestScore = -1e9;
  for (final track in tracks) {
    final score = _score(track, title, artist, seconds);
    if (score > bestScore) {
      best = track;
      bestScore = score;
    }
  }
  if (best == null || (best['has_subtitles'] as num?)?.toInt() != 1) {
    return null;
  }

  final trackId = (best['track_id'] as num?)?.toInt();
  if (trackId == null) return null;

  final subtitle = await _fetchSubtitle(trackId);
  if (subtitle == null) return null;
  final lrc = _subtitleToLrc(subtitle);
  if (lrc.isEmpty) return null;

  final lines = parseLrc(lrc);
  return lines.isEmpty ? null : lines;
}

double _score(
  Map<String, dynamic> track,
  String title,
  String artist,
  int seconds,
) {
  var score = 0.0;
  final name = (track['track_name'] as String? ?? '').trim().toLowerCase();
  final wanted = title.trim().toLowerCase();
  if (name == wanted) {
    score += 80;
  } else if (name.contains(wanted) || wanted.contains(name)) {
    score += 40;
  }
  final artistName = (track['artist_name'] as String? ?? '')
      .trim()
      .toLowerCase();
  if (artistName.contains(artist.trim().toLowerCase())) score += 40;

  final length = (track['track_length'] as num?)?.toInt();
  if (length != null && seconds > 0) {
    final diff = (length - seconds).abs();
    score += switch (diff) {
      <= 2 => 30.0,
      <= 5 => 15.0,
      <= 10 => 5.0,
      _ => -20.0,
    };
  }
  return score;
}

Future<List<Map<String, dynamic>>?> _searchTrack(
  String title,
  String artist,
) async {
  final body = await _signedGet(
    (token) => Uri.parse('${Env.musixmatchBase}/track.search').replace(
      queryParameters: {
        'app_id': _appId,
        'q_track': title,
        'q_artist': artist,
        'f_has_lyrics': '1',
        's_track_rating': 'desc',
        'quorum_factor': '1',
        'page_size': '10',
        'page': '1',
        'usertoken': token,
      },
    ),
  );
  if (body == null) return null;
  final list = _bodyOf(body)?['track_list'];
  if (list is! List) return null;
  return list
      .whereType<Map>()
      .map((m) => (m['track'] as Map?)?.cast<String, dynamic>())
      .whereType<Map<String, dynamic>>()
      .toList();
}

Future<String?> _fetchSubtitle(int trackId) async {
  final body = await _signedGet(
    (token) => Uri.parse('${Env.musixmatchBase}/track.subtitle.get').replace(
      queryParameters: {
        'app_id': _appId,
        'track_id': '$trackId',
        'subtitle_format': 'mxm',
        'usertoken': token,
      },
    ),
  );
  if (body == null) return null;
  final subtitle = _bodyOf(body)?['subtitle'];
  return (subtitle as Map?)?['subtitle_body'] as String?;
}

String _subtitleToLrc(String subtitleBody) {
  late final List<dynamic> rows;
  try {
    final decoded = jsonDecode(subtitleBody);
    if (decoded is! List) return '';
    rows = decoded;
  } on Object {
    return '';
  }

  final out = StringBuffer();
  for (final row in rows) {
    if (row is! Map) continue;
    final text = row['text'] as String?;
    if (text == null || text.trim().isEmpty) continue;
    final total = ((row['time'] as Map?)?['total'] as num?)?.toDouble();
    if (total == null) continue;

    final totalMs = (total * 1000).round();
    final minutes = (totalMs ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((totalMs ~/ 1000) % 60).toString().padLeft(2, '0');
    final millis = (totalMs % 1000).toString().padLeft(3, '0');
    out.writeln('[$minutes:$seconds.$millis]$text');
  }
  return out.toString().trim();
}

Future<String?> _signedGet(Uri Function(String token) buildUrl) async {
  final token = await _token();
  if (token == null) return null;

  final first = await lyricsGet(_sign(buildUrl(token)));
  if (first != null && !_looksUnauthorized(first)) return first;

  _cachedToken = null;
  final fresh = await _token();
  if (fresh == null) return null;
  return lyricsGet(_sign(buildUrl(fresh)));
}

bool _looksUnauthorized(String body) {
  try {
    final header = ((jsonDecode(body) as Map?)?['message'] as Map?)?['header'];
    final status = ((header as Map?)?['status_code'] as num?)?.toInt();
    return status == 401 || status == 402;
  } on Object {
    return false;
  }
}

Map<String, dynamic>? _bodyOf(String response) {
  try {
    final message = (jsonDecode(response) as Map?)?['message'];
    return ((message as Map?)?['body'] as Map?)?.cast<String, dynamic>();
  } on Object {
    return null;
  }
}

Future<String?> _token() {
  final cached = _cachedToken;
  if (cached != null) return Future.value(cached);
  return _tokenInFlight ??= _fetchToken().whenComplete(() {
    _tokenInFlight = null;
  });
}

Future<String?> _fetchToken() async {
  final url = Uri.parse(
    '${Env.musixmatchBase}/token.get',
  ).replace(queryParameters: {'app_id': _appId});
  final body = await lyricsGet(_sign(url));
  if (body == null) return null;
  return _cachedToken = _bodyOf(body)?['user_token'] as String?;
}

String _sign(Uri url) {
  final now = DateTime.now().toUtc();
  final date =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';

  final raw = url.toString();
  final mac = Hmac(sha256, utf8.encode(Env.musixmatchSecret));
  final digest = mac.convert(utf8.encode('$raw$date'));
  final signature = Uri.encodeQueryComponent(base64.encode(digest.bytes));

  return '$raw&signature=$signature&signature_protocol=sha256';
}
