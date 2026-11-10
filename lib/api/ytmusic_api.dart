import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'dto.dart';
import 'yt_auth_channel.dart';
import 'yt_locale.dart';

part 'ytmusic_renderers.dart';
part 'ytmusic_account.dart';

typedef AuthHeaders = Future<Map<String, String>> Function();

const _kClientName = 'WEB_REMIX';
const _kClientVersion = '1.20260101.01.00';
const _kBase = Env.ytMusicBase;

const _kMaxContinuationPages = 25;

const _kSongsOnlyParams = 'EgWKAQIIAWoKEAoQAxAEEAkQBQ%3D%3D';
const _kArtistsOnlyParams = 'EgWKAQIgAWoKEAoQAxAEEAkQBQ%3D%3D';
const _kAlbumsOnlyParams = 'EgWKAQIYAWoKEAoQAxAEEAkQBQ%3D%3D';

class YtCategoryChip {
  const YtCategoryChip({
    required this.title,
    required this.browseId,
    required this.params,
    this.color,
  });
  final String title;
  final String browseId;
  final String params;
  final int? color;
}

class YtCategoryGroup {
  const YtCategoryGroup({required this.title, required this.chips});
  final String title;
  final List<YtCategoryChip> chips;
}

class YtPlaylistDetail {
  const YtPlaylistDetail({
    required this.id,
    required this.title,
    required this.tracks,
    this.subtitle,
    this.description,
    this.artwork,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? artwork;
  final List<FeedItem> tracks;
}

class YtArtistDetail {
  const YtArtistDetail({
    required this.id,
    required this.name,
    required this.topSongs,
    required this.sections,
    this.subtitle,
    this.description,
    this.artwork,
    this.radioVideoId,
    this.radioPlaylistId,
    this.shuffleVideoId,
    this.shufflePlaylistId,
  });
  final String id;
  final String name;
  final String? subtitle;
  final String? description;
  final String? artwork;
  final List<FeedItem> topSongs;
  final List<HomeSection> sections;

  final String? radioVideoId;
  final String? radioPlaylistId;

  final String? shuffleVideoId;
  final String? shufflePlaylistId;

  bool get hasRadio =>
      (radioPlaylistId ?? '').isNotEmpty && (radioVideoId ?? '').isNotEmpty;
}

const int _kHomeExtraPages = 4;

class YtMusicApi {
  YtMusicApi(this._dio, {this.locale = YtLocale.fallback, AuthHeaders? auth})
    : _auth = auth ?? YtAuthChannel.instance.headers;
  final Dio _dio;

  final AuthHeaders _auth;

  final YtLocale locale;

  Map<String, dynamic> get _context => {
    'context': {
      'client': {
        'clientName': _kClientName,
        'clientVersion': _kClientVersion,
        'hl': locale.language,
        'gl': locale.country,
      },
    },
  };

  Options _optionsWith(Map<String, String> auth) => Options(
    headers: {
      'Content-Type': 'application/json',
      'X-Youtube-Client-Name': '67',
      'X-Youtube-Client-Version': _kClientVersion,
      'Origin': 'https://music.youtube.com',
      ...auth,
    },
    validateStatus: (s) => s != null && s < 500,
  );

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final auth = await _auth();
    final res = await _dio.post<Map<String, dynamic>>(
      '$_kBase/$path?prettyPrint=false',
      data: _withVisitorData(body, auth['X-Goog-Visitor-Id']),
      options: _optionsWith(auth),
    );
    return res.data;
  }

  static Map<String, dynamic> _withVisitorData(
    Map<String, dynamic> body,
    String? visitorData,
  ) {
    if (visitorData == null || visitorData.isEmpty) return body;
    final context = body['context'];
    if (context is! Map) return body;
    final client = context['client'];
    if (client is! Map) return body;
    return {
      ...body,
      'context': {
        ...context.cast<String, dynamic>(),
        'client': {
          ...client.cast<String, dynamic>(),
          'visitorData': visitorData,
        },
      },
    };
  }

  Future<List<FeedItem>> searchSongs(String query) async {
    if (query.trim().isEmpty) return const [];
    final body = await _post('search', {
      ..._context,
      'query': query,
      'params': _kSongsOnlyParams,
    });
    if (body == null) return const [];
    final out = <FeedItem>[];
    for (final shelf in _searchShelves(body)) {
      for (final raw in _asList(shelf['contents'])) {
        final item = _parseResponsiveItem(_asMap(raw));
        if (item != null) out.add(item);
      }
    }
    return out;
  }

  Future<List<FeedItem>> searchArtists(String query) =>
      _searchFiltered(query, _kArtistsOnlyParams);

  Future<List<FeedItem>> searchAlbums(String query) =>
      _searchFiltered(query, _kAlbumsOnlyParams);

  Future<List<FeedItem>> _searchFiltered(String query, String params) async {
    if (query.trim().isEmpty) return const [];
    try {
      final body = await _post('search', {
        ..._context,
        'query': query,
        'params': params,
      });
      if (body == null) return const [];
      final out = <FeedItem>[];
      for (final shelf in _searchShelves(body)) {
        for (final raw in _asList(shelf['contents'])) {
          final item = _parseResponsiveItem(_asMap(raw));
          if (item != null) out.add(item);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<HomeSection>> home() async {
    final pages = await Future.wait([
      _browseSections('FEmusic_home', extraPages: _kHomeExtraPages),
      _browseSections('FEmusic_explore'),
      _browseSections('FEmusic_charts'),
      _browseSections('FEmusic_new_releases'),
    ]);

    final seen = <String>{};
    final out = <HomeSection>[];
    for (final section in pages.expand((p) => p)) {
      final key = section.heading.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      if (key.contains('moods') || key.contains('genres')) continue;
      out.add(section);
    }
    return out;
  }

  Future<List<HomeSection>> _browseSections(
    String browseId, {
    int extraPages = 0,
  }) async {
    try {
      final body = await _post('browse', {..._context, 'browseId': browseId});
      if (body == null) return const [];
      final sections = [..._carouselSections(_singleColumnShelves(body))];

      var token = extraPages > 0 ? _continuationOf(body) : null;
      for (var page = 0; page < extraPages && token != null; page++) {
        final next = await _post('browse', {
          ..._context,
          'continuation': token,
        });
        if (next == null) break;
        final shelves = _continuationShelves(next);
        if (shelves.isEmpty) break;
        sections.addAll(_carouselSections(shelves));
        token = _continuationOf(next);
      }
      debugPrint(
        '[ytmusic] $browseId: ${sections.length} sections '
        'over ${extraPages > 0 ? 'up to ${extraPages + 1}' : '1'} page(s)',
      );
      return sections;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _continuationRows(String? token) async {
    final rows = <Map<String, dynamic>>[];
    var next = token;
    for (var page = 0; page < _kMaxContinuationPages && next != null; page++) {
      final body = await _post('browse', {..._context, 'continuation': next});
      if (body == null) break;
      final items = _continuationShelves(body);
      if (items.isEmpty) break;
      rows.addAll(items);
      next = _continuationOf(body);
    }
    if (next != null) {
      debugPrint(
        '[ytmusic] stopped after $_kMaxContinuationPages continuation pages '
        '(${rows.length} rows) with more still to come',
      );
    }
    return rows;
  }

  Future<YtArtistDetail?> artist(String browseId) async {
    final body = await _post('browse', {..._context, 'browseId': browseId});
    if (body == null) {
      print('[ytmusic] artist $browseId: empty response');
      return null;
    }

    final header = _artistHeader(body);
    final name = _runsText(_asMap(header?['title']));
    if (name.isEmpty) {
      print(
        '[ytmusic] artist $browseId: no name. '
        'top=${body.keys.toList()} '
        'header=${_asMap(body['header'])?.keys.toList()} '
        'contents=${_asMap(body['contents'])?.keys.toList()}',
      );
      return null;
    }

    final thumbs = header == null ? const <ApiImage>[] : _thumbnails(header);
    final artistArt = _largestArt(thumbs);
    final description = _runsText(_asMap(header?['description']));
    final listeners = _runsText(_asMap(header?['monthlyListenerCount']));

    var radio = _watchSeed(_asMap(header?['startRadioButton']));
    var play = _watchSeed(_asMap(header?['playButton']));
    if (radio == null || play == null) {
      for (final b in _asList(header?['buttons'])) {
        final seed = _watchSeed(_asMap(b));
        if (seed == null) continue;
        if (seed.$2.startsWith('RD')) {
          radio ??= seed;
        } else {
          play ??= seed;
        }
      }
    }

    final topSongs = <FeedItem>[];
    final sections = <HomeSection>[];
    for (final shelf in _artistShelves(body)) {
      final list = _asMap(shelf['musicShelfRenderer']);
      if (list != null) {
        for (final raw in _asList(list['contents'])) {
          final item = _parseResponsiveItem(_asMap(raw));
          if (item != null) topSongs.add(item);
        }
        continue;
      }
      sections.addAll(_carouselSections([shelf]));
    }

    return YtArtistDetail(
      id: browseId,
      name: name,
      subtitle: listeners.isEmpty ? null : listeners,
      description: description.isEmpty ? null : description,
      artwork: artistArt,
      topSongs: topSongs,
      sections: sections,
      radioVideoId: radio?.$1,
      radioPlaylistId: radio?.$2,
      shuffleVideoId: play?.$1,
      shufflePlaylistId: play?.$2,
    );
  }

  Future<List<FeedItem>> radioQueue({
    required String videoId,
    required String playlistId,
  }) async {
    final body = await _post('next', {
      ..._context,
      'videoId': videoId,
      'playlistId': playlistId,
      'isAudioOnly': true,
    });
    if (body == null) return const [];
    final tabs = _asList(
      _dig(body, [
        'contents',
        'singleColumnMusicWatchNextResultsRenderer',
        'tabbedRenderer',
        'watchNextTabbedResultsRenderer',
        'tabs',
      ]),
    );
    for (final tab in tabs) {
      final items = _asList(
        _dig(_asMap(tab), [
          'tabRenderer',
          'content',
          'musicQueueRenderer',
          'content',
          'playlistPanelRenderer',
          'contents',
        ]),
      );
      final out = <FeedItem>[];
      for (final raw in items) {
        final r = _asMap(_asMap(raw)?['playlistPanelVideoRenderer']);
        if (r == null) continue;
        final id = r['videoId'] as String?;
        final title = _runsText(_asMap(r['title']));
        if (id == null || id.isEmpty || title.isEmpty) continue;
        final byline = _runsText(_asMap(r['longBylineText'])).split(' • ');
        out.add(
          FeedItem(
            id: id,
            title: title,
            type: 'song',
            source: 'youtube',
            image: _thumbnails(r),
            subtitle: byline.isEmpty ? null : byline.first,
            duration: _durationToSeconds(
              _runsText(_asMap(r['lengthText'])),
            )?.toString(),
          ),
        );
      }
      if (out.isNotEmpty) return out;
    }
    return const [];
  }

  Map<String, dynamic>? _artistHeader(Map<String, dynamic> body) {
    final immersive = _asMap(
      _dig(body, ['header', 'musicImmersiveHeaderRenderer']),
    );
    if (immersive != null) return immersive;

    for (final tab in _asList(
      _dig(body, ['contents', 'twoColumnBrowseResultsRenderer', 'tabs']),
    )) {
      for (final sec in _asList(
        _dig(_asMap(tab), [
          'tabRenderer',
          'content',
          'sectionListRenderer',
          'contents',
        ]),
      )) {
        final m = _asMap(sec);
        final h =
            _asMap(m?['musicResponsiveHeaderRenderer']) ??
            _asMap(m?['musicImmersiveHeaderRenderer']);
        if (h != null) return h;
      }
    }
    return _asMap(_dig(body, ['header', 'musicHeaderRenderer'])) ??
        _asMap(_dig(body, ['header', 'musicVisualHeaderRenderer']));
  }

  List<Map<String, dynamic>> _artistShelves(Map<String, dynamic> body) {
    final single = _singleColumnShelves(body);
    if (single.isNotEmpty) return single;
    final out = <Map<String, dynamic>>[];
    for (final sec in _asList(
      _dig(body, [
        'contents',
        'twoColumnBrowseResultsRenderer',
        'secondaryContents',
        'sectionListRenderer',
        'contents',
      ]),
    )) {
      final m = _asMap(sec);
      if (m != null) out.add(m);
    }
    return out;
  }

  (String, String)? _watchSeed(Map<String, dynamic>? button) {
    final we = _asMap(
      _dig(button, ['buttonRenderer', 'navigationEndpoint', 'watchEndpoint']),
    );
    final v = we?['videoId'] as String?;
    final p = we?['playlistId'] as String?;
    if (v == null || p == null || v.isEmpty || p.isEmpty) return null;
    return (v, p);
  }

  Future<List<YtCategoryGroup>> moodsAndGenres() async {
    final body = await _post('browse', {
      ..._context,
      'browseId': 'FEmusic_moods_and_genres',
    });
    if (body == null) return const [];
    final groups = <YtCategoryGroup>[];
    for (final sec in _singleColumnShelves(body)) {
      final grid = _asMap(sec['gridRenderer']);
      if (grid == null) continue;
      final title = _runsText(
        _asMap(_dig(grid, ['header', 'gridHeaderRenderer', 'title'])),
      );
      final chips = <YtCategoryChip>[];
      for (final raw in _asList(grid['items'])) {
        final btn = _asMap(_asMap(raw)?['musicNavigationButtonRenderer']);
        if (btn == null) continue;
        final label = _runsText(_asMap(btn['buttonText']));
        final endpoint = _asMap(_dig(btn, ['clickCommand', 'browseEndpoint']));
        final browseId = endpoint?['browseId'] as String?;
        final params = endpoint?['params'] as String?;
        if (label.isEmpty || browseId == null || params == null) continue;
        chips.add(
          YtCategoryChip(
            title: label,
            browseId: browseId,
            params: params,
            color: (_dig(btn, ['solid', 'leftStripeColor']) as num?)?.toInt(),
          ),
        );
      }
      if (chips.isNotEmpty) {
        groups.add(
          YtCategoryGroup(
            title: title.isEmpty ? 'Browse' : title,
            chips: chips,
          ),
        );
      }
    }
    return groups;
  }

  Future<List<HomeSection>> category(String browseId, String params) async {
    final body = await _post('browse', {
      ..._context,
      'browseId': browseId,
      'params': params,
    });
    if (body == null) return const [];
    return _carouselSections(_singleColumnShelves(body));
  }

  Future<YtPlaylistDetail?> playlist(String browseId) async {
    final body = await _post('browse', {..._context, 'browseId': browseId});
    if (body == null) return null;
    final two = _asMap(
      _dig(body, ['contents', 'twoColumnBrowseResultsRenderer']),
    );
    if (two == null) {
      debugPrint(
        '[ytmusic] $browseId: not a two-column playlist. top-level: '
        '${_asMap(body['contents'])?.keys.toList()}',
      );
      return null;
    }

    String title = '';
    String? subtitle;
    String? description;
    String? artwork;
    for (final name in const [
      'musicResponsiveHeaderRenderer',
      'musicDetailHeaderRenderer',
      'musicEditablePlaylistDetailHeaderRenderer',
      'musicImmersiveHeaderRenderer',
    ]) {
      final h = _findRenderer(body, name);
      if (h == null) continue;
      final found = _runsText(_asMap(h['title']));
      if (found.isEmpty) continue;
      title = found;
      subtitle = _runsText(_asMap(h['subtitle']));
      description = _runsText(_asMap(h['description']));
      artwork = _largestArt(_thumbnails(h));
      break;
    }

    if (title.isEmpty) {
      final micro = _findRenderer(body, 'microformatDataRenderer');
      if (micro != null) {
        title = (micro['title'] as String?) ?? '';
        artwork ??= _largestArt(_thumbnails(micro));
      }
    }
    if (title.isEmpty) {
      debugPrint(
        '[ytmusic] $browseId: no header matched. present: '
        '${headerRendererNames(body)}',
      );
    }

    final tracks = <FeedItem>[];
    final secContents = _asList(
      _dig(two, ['secondaryContents', 'sectionListRenderer', 'contents']),
    );
    String? more;
    for (final sec in secContents) {
      final shelf =
          _asMap(_asMap(sec)?['musicPlaylistShelfRenderer']) ??
          _asMap(_asMap(sec)?['musicShelfRenderer']);
      if (shelf == null) continue;
      for (final raw in _asList(shelf['contents'])) {
        final item = _parseResponsiveItem(_asMap(raw));
        if (item != null) tracks.add(item);
      }
      more ??= _continuationOf(shelf);
    }
    for (final raw in await _continuationRows(more)) {
      final item = _parseResponsiveItem(_asMap(raw));
      if (item != null) tracks.add(item);
    }

    final headerArt = artwork;
    final withArt = headerArt == null
        ? tracks
        : [
            for (final t in tracks)
              t.image.isNotEmpty
                  ? t
                  : _withImages(t, [
                      ApiImage(
                        quality: '${_kMaxArtSize}x$_kMaxArtSize',
                        link: headerArt,
                      ),
                    ]),
          ];

    if (title.isEmpty && withArt.isEmpty) return null;
    return YtPlaylistDetail(
      id: browseId,
      title: title.isEmpty ? 'Playlist' : title,
      subtitle: (subtitle ?? '').isEmpty ? null : subtitle,
      description: (description ?? '').isEmpty ? null : description,
      artwork: artwork,
      tracks: withArt,
    );
  }

  FeedItem _withImages(FeedItem item, List<ApiImage> image) => FeedItem(
    id: item.id,
    title: item.title,
    type: item.type,
    image: image,
    subtitle: item.subtitle,
    source: item.source,
    language: item.language,
    url: item.url,
    duration: item.duration,
    songCount: item.songCount,
    playCount: item.playCount,
    releaseDate: item.releaseDate,
    artists: item.artists,
    token: item.token,
    stationType: item.stationType,
    mediaUrls: item.mediaUrls,
  );
}
