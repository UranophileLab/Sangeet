part of 'ytmusic_api.dart';

const _kLikedSongs = 'FEmusic_liked_videos';
const _kLikedPlaylists = 'FEmusic_liked_playlists';
const _kLikedAlbums = 'FEmusic_liked_albums';
const _kLibraryArtists = 'FEmusic_library_corpus_track_artists';

extension YtMusicAccount on YtMusicApi {
  Future<String?> accountName() async {
    try {
      final body = await _post('account/account_menu', _context);
      if (body == null) return null;
      final header = _findRenderer(body, 'activeAccountHeaderRenderer');
      final name = _nodeText(_asMap(header?['accountName']));
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  Future<List<HomeSection>> library() async {
    final pages = await Future.wait([
      _libraryPage(_kLikedSongs, 'Liked songs'),
      _libraryPage(_kLikedPlaylists, 'Your playlists'),
      _libraryPage(_kLikedAlbums, 'Your albums'),
      _libraryPage(_kLibraryArtists, 'Your artists'),
    ]);
    return [for (final page in pages) if (page != null) page];
  }

  Future<HomeSection?> _libraryPage(String browseId, String heading) async {
    try {
      final body = await _post('browse', {..._context, 'browseId': browseId});
      if (body == null) return null;
      final shelves = _singleColumnShelves(body);
      final items = _libraryItems(shelves);
      String? more;
      for (final shelf in shelves) {
        more ??= _continuationOf(shelf);
      }
      for (final raw in await _continuationRows(more)) {
        final m = _asMap(raw);
        if (m == null) continue;
        final item = _parseTwoRowItem(m) ?? _parseResponsiveItem(m);
        if (item != null) items.add(item);
      }
      if (items.isEmpty) return null;
      return HomeSection(heading: heading, items: items, source: 'youtube');
    } catch (_) {
      return null;
    }
  }
}

List<FeedItem> _libraryItems(List<Map<String, dynamic>> shelves) {
  final items = <FeedItem>[];
  for (final shelf in shelves) {
    final containers = [
      _asMap(shelf['gridRenderer']),
      _asMap(shelf['musicShelfRenderer']),
      _asMap(shelf['musicCarouselShelfRenderer']),
    ];
    for (final container in containers) {
      if (container == null) continue;
      for (final raw in [
        ..._asList(container['items']),
        ..._asList(container['contents']),
      ]) {
        final m = _asMap(raw);
        if (m == null) continue;
        final item = _parseTwoRowItem(m) ?? _parseResponsiveItem(m);
        if (item != null) items.add(item);
      }
    }
  }
  return items;
}

Map<String, dynamic>? _findRenderer(Object? node, String key, [int depth = 0]) {
  if (depth > 12) return null;
  if (node is Map) {
    final here = node[key];
    if (here is Map) return here.cast<String, dynamic>();
    for (final value in node.values) {
      final found = _findRenderer(value, key, depth + 1);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final value in node) {
      final found = _findRenderer(value, key, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

String _nodeText(Map<String, dynamic>? node) {
  if (node == null) return '';
  final runs = _runsText(node);
  if (runs.isNotEmpty) return runs;
  final simple = node['simpleText'];
  return simple is String ? simple : '';
}
