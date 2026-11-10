part of 'ytmusic_api.dart';

List<HomeSection> _carouselSections(List<Map<String, dynamic>> shelves) {
  final sections = <HomeSection>[];
  for (final shelf in shelves) {
    final carousel = _asMap(shelf['musicCarouselShelfRenderer']);
    if (carousel == null) continue;
    final heading = _runsText(
      _asMap(
        _dig(carousel, [
          'header',
          'musicCarouselShelfBasicHeaderRenderer',
          'title',
        ]),
      ),
    );
    final items = <FeedItem>[];
    for (final raw in _asList(carousel['contents'])) {
      final m = _asMap(raw);
      if (m == null) continue;
      final item = _parseTwoRowItem(m) ?? _parseResponsiveItem(m);
      if (item != null) items.add(item);
    }
    if (items.isNotEmpty) {
      sections.add(
        HomeSection(
          heading: heading.isEmpty ? 'YouTube Music' : heading,
          items: items,
          source: 'youtube',
        ),
      );
    }
  }
  return sections;
}

List<Map<String, dynamic>> _searchShelves(Map<String, dynamic> body) {
  final tabs = _asList(
    _dig(body, ['contents', 'tabbedSearchResultsRenderer', 'tabs']),
  );
  for (final tab in tabs) {
    final shelves = <Map<String, dynamic>>[];
    for (final c in _asList(
      _dig(_asMap(tab), [
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
      ]),
    )) {
      final shelf = _asMap(_asMap(c)?['musicShelfRenderer']);
      if (shelf != null) shelves.add(shelf);
    }
    if (shelves.isNotEmpty) return shelves;
  }
  return const [];
}

List<Map<String, dynamic>> _singleColumnShelves(Map<String, dynamic> body) {
  final tabs = _asList(
    _dig(body, ['contents', 'singleColumnBrowseResultsRenderer', 'tabs']),
  );
  for (final tab in tabs) {
    final contents = _asList(
      _dig(_asMap(tab), [
        'tabRenderer',
        'content',
        'sectionListRenderer',
        'contents',
      ]),
    );
    if (contents.isNotEmpty) {
      return contents.map(_asMap).whereType<Map<String, dynamic>>().toList();
    }
  }
  return const [];
}

FeedItem? _parseResponsiveItem(Map<String, dynamic>? wrapper) {
  final r = _asMap(wrapper?['musicResponsiveListItemRenderer']);
  if (r == null) return null;

  final cols = _asList(r['flexColumns']);
  final title = _flexColumnText(cols, 0);
  if (title.isEmpty) return null;

  final videoId = _videoIdOf(r);
  if (videoId == null) {
    final nav = _asMap(r['navigationEndpoint']);
    final browseId = _asMap(nav?['browseEndpoint'])?['browseId'] as String?;
    if (browseId == null || browseId.isEmpty) return null;
    final type = switch (_pageTypeOf(nav)) {
      'MUSIC_PAGE_TYPE_ARTIST' => 'artist',
      'MUSIC_PAGE_TYPE_ALBUM' => 'album',
      'MUSIC_PAGE_TYPE_PLAYLIST' => 'playlist',
      _ => null,
    };
    if (type == null) return null;
    final sub = _flexColumnText(cols, 1).trim();
    return FeedItem(
      id: browseId,
      title: title,
      type: type,
      source: 'youtube',
      image: _thumbnails(r),
      subtitle: sub.isEmpty ? null : sub,
    );
  }

  final subRuns = _flexColumnRuns(cols, 1);
  final artists = <ApiArtistRef>[];
  String? album;
  String? duration;
  for (final run in subRuns) {
    final text = (run['text'] ?? '').toString();
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == '•') continue;

    final secs = _durationToSeconds(trimmed);
    if (secs != null) {
      duration = '$secs';
      continue;
    }

    final nav = _asMap(run['navigationEndpoint']);
    switch (_pageTypeOf(nav)) {
      case 'MUSIC_PAGE_TYPE_ARTIST':
        artists.add(
          ApiArtistRef(
            id: (_asMap(nav?['browseEndpoint'])?['browseId'] ?? '').toString(),
            name: trimmed,
          ),
        );
      case 'MUSIC_PAGE_TYPE_ALBUM':
        album ??= trimmed;
      case _:
        if (artists.isEmpty && album == null) {
          artists.add(ApiArtistRef(id: '', name: trimmed));
        }
    }
  }

  final third = _flexColumnText(cols, 2).trim();
  final plays = third.toLowerCase().contains('play') ? third : null;

  return FeedItem(
    id: videoId,
    title: title,
    type: 'song',
    source: 'youtube',
    image: _thumbnails(r),
    subtitle: artists.isEmpty ? album : artists.map((a) => a.name).join(', '),
    duration: duration,
    playCount: plays,
    artists: List.unmodifiable(artists),
  );
}

FeedItem? _parseTwoRowItem(Map<String, dynamic> wrapper) {
  final r = _asMap(wrapper['musicTwoRowItemRenderer']);
  if (r == null) return null;

  final title = _runsText(_asMap(r['title']));
  if (title.isEmpty) return null;
  final subtitle = _runsText(_asMap(r['subtitle']));

  final nav = _asMap(r['navigationEndpoint']);
  final videoId = _asMap(nav?['watchEndpoint'])?['videoId'] as String?;
  final browseId = _asMap(nav?['browseEndpoint'])?['browseId'] as String?;

  final String id;
  final String type;
  if (videoId != null && videoId.isNotEmpty) {
    id = videoId;
    type = 'song';
  } else if (browseId != null && browseId.isNotEmpty) {
    id = browseId;
    type = switch (_pageTypeOf(nav)) {
      'MUSIC_PAGE_TYPE_ARTIST' => 'artist',
      'MUSIC_PAGE_TYPE_ALBUM' => 'album',
      _ => 'playlist',
    };
  } else {
    return null;
  }

  return FeedItem(
    id: id,
    title: title,
    type: type,
    source: 'youtube',
    image: _thumbnails(r),
    subtitle: subtitle.isEmpty ? null : subtitle,
  );
}

String? _pageTypeOf(Map<String, dynamic>? navigationEndpoint) =>
    _dig(navigationEndpoint, [
          'browseEndpoint',
          'browseEndpointContextSupportedConfigs',
          'browseEndpointContextMusicConfig',
          'pageType',
        ])
        as String?;

String? _videoIdOf(Map<String, dynamic> r) {
  final fromPlaylistData = _asMap(r['playlistItemData'])?['videoId'] as String?;
  if (fromPlaylistData != null && fromPlaylistData.isNotEmpty) {
    return fromPlaylistData;
  }
  final overlayId = _dig(r, [
    'overlay',
    'musicItemThumbnailOverlayRenderer',
    'content',
    'musicPlayButtonRenderer',
    'playNavigationEndpoint',
    'watchEndpoint',
    'videoId',
  ]);
  if (overlayId is String && overlayId.isNotEmpty) return overlayId;
  return null;
}

List<ApiImage> _thumbnails(Map<String, dynamic> r) {
  final candidates = <List<String>>[
    ['thumbnail', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails'],
    ['thumbnailRenderer', 'musicThumbnailRenderer', 'thumbnail', 'thumbnails'],
    ['thumbnail', 'thumbnails'],
  ];
  for (final path in candidates) {
    final thumbs = _asList(_dig(r, path));
    if (thumbs.isEmpty) continue;
    final out = <ApiImage>[];
    for (final t in thumbs) {
      final m = _asMap(t);
      final url = m?['url'] as String?;
      if (url == null || url.isEmpty) continue;
      final w = (m?['width'] as num?)?.toInt();
      final h = (m?['height'] as num?)?.toInt();
      final upscaled = _upscale(url, w, h);
      out.add(
        ApiImage(
          quality: upscaled.$2 == null ? '' : '${upscaled.$2}x${upscaled.$3}',
          link: upscaled.$1,
        ),
      );
    }
    if (out.isNotEmpty) return out;
  }
  return const [];
}

String? _largestArt(List<ApiImage> images) {
  if (images.isEmpty) return null;
  int width(ApiImage i) {
    final m = RegExp(r'(\d+)').firstMatch(i.quality);
    return m == null ? 0 : (int.tryParse(m.group(1)!) ?? 0);
  }

  final sorted = [...images]..sort((a, b) => width(b).compareTo(width(a)));
  return sorted.first.link;
}

const _kMaxArtSize = 1200;

(String, int?, int?) _upscale(String url, int? width, int? height) {
  if (width != null && width >= _kMaxArtSize) return (url, width, height);

  final square = RegExp(r'=s(\d+)').firstMatch(url);
  if (square != null) {
    return (
      url.replaceRange(square.start, square.end, '=s$_kMaxArtSize'),
      _kMaxArtSize,
      _kMaxArtSize,
    );
  }

  final sized = RegExp(r'=w(\d+)-h(\d+)').firstMatch(url);
  if (sized != null) {
    final w0 = int.tryParse(sized.group(1)!) ?? 0;
    final h0 = int.tryParse(sized.group(2)!) ?? 0;
    final h = (w0 > 0 && h0 > 0)
        ? (_kMaxArtSize * h0 / w0).round()
        : _kMaxArtSize;
    return (
      url.replaceRange(sized.start, sized.end, '=w$_kMaxArtSize-h$h'),
      _kMaxArtSize,
      h,
    );
  }

  return (url, width, height);
}

String _flexColumnText(List<dynamic> cols, int index) => _flexColumnRuns(
  cols,
  index,
).map((r) => (r['text'] ?? '').toString()).join();

List<Map<String, dynamic>> _flexColumnRuns(List<dynamic> cols, int index) {
  if (index >= cols.length) return const [];
  return _asList(
    _dig(_asMap(cols[index]), [
      'musicResponsiveListItemFlexColumnRenderer',
      'text',
      'runs',
    ]),
  ).map(_asMap).whereType<Map<String, dynamic>>().toList();
}

String _runsText(Map<String, dynamic>? node) => _asList(node?['runs'])
    .map(_asMap)
    .whereType<Map<String, dynamic>>()
    .map((r) => (r['text'] ?? '').toString())
    .join();

int? _durationToSeconds(String text) {
  if (!RegExp(r'^\d{1,2}(:\d{2}){1,2}$').hasMatch(text)) return null;
  final parts = text.split(':').map(int.parse).toList();
  return switch (parts.length) {
    2 => parts[0] * 60 + parts[1],
    3 => parts[0] * 3600 + parts[1] * 60 + parts[2],
    _ => null,
  };
}

Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

List<dynamic> _asList(Object? v) => v is List ? v : const [];

Object? _dig(Map<String, dynamic>? node, List<String> path) {
  Object? cur = node;
  for (final key in path) {
    final m = _asMap(cur);
    if (m == null) return null;
    cur = m[key];
  }
  return cur;
}

String? _continuationOf(Map<String, dynamic> body) {
  for (final node in _deepList(body, 'continuations')) {
    final token = _dig(_asMap(node), ['nextContinuationData', 'continuation']);
    if (token is String && token.isNotEmpty) return token;
  }
  final item = _findRenderer(body, 'continuationItemRenderer');
  final token = _dig(item, [
    'continuationEndpoint',
    'continuationCommand',
    'token',
  ]);
  return token is String && token.isNotEmpty ? token : null;
}

List<Map<String, dynamic>> _continuationShelves(Map<String, dynamic> body) {
  final out = <Map<String, dynamic>>[];
  for (final key in const [
    ['continuationContents', 'sectionListContinuation', 'contents'],
    ['continuationContents', 'musicShelfContinuation', 'contents'],
    ['continuationContents', 'musicPlaylistShelfContinuation', 'contents'],
    ['continuationContents', 'gridContinuation', 'items'],
  ]) {
    for (final raw in _asList(_dig(body, key))) {
      final m = _asMap(raw);
      if (m != null) out.add(m);
    }
  }
  for (final action in _asList(body['onResponseReceivedActions'])) {
    for (final raw in _asList(
      _dig(_asMap(action), [
        'appendContinuationItemsAction',
        'continuationItems',
      ]),
    )) {
      final m = _asMap(raw);
      if (m != null) out.add(m);
    }
  }
  return out;
}

List<String> headerRendererNames(Object? node, [int depth = 0]) {
  final found = <String>{};
  void walk(Object? n, int d) {
    if (d > 12) return;
    if (n is Map) {
      for (final entry in n.entries) {
        final key = entry.key;
        if (key is String && key.endsWith('HeaderRenderer')) found.add(key);
        walk(entry.value, d + 1);
      }
    } else if (n is List) {
      for (final v in n) {
        walk(v, d + 1);
      }
    }
  }

  walk(node, depth);
  return found.toList()..sort();
}

List<Object?> _deepList(Object? node, String key, [int depth = 0]) {
  if (depth > 8) return const [];
  final out = <Object?>[];
  if (node is Map) {
    for (final entry in node.entries) {
      if (entry.key == key) out.addAll(_asList(entry.value));
      out.addAll(_deepList(entry.value, key, depth + 1));
    }
  } else if (node is List) {
    for (final value in node) {
      out.addAll(_deepList(value, key, depth + 1));
    }
  }
  return out;
}
