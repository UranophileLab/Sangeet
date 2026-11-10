import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dto.dart';
import 'local_sort.dart';

class LocalCollection {
  const LocalCollection({
    required this.id,
    required this.name,
    required this.songs,
    this.subtitle,
  });

  final String id;
  final String name;
  final String? subtitle;
  final List<FeedItem> songs;

  String? get artwork {
    for (final s in songs) {
      final art = s.artwork;
      if (art != null && art.isNotEmpty) return art;
    }
    return null;
  }
}

class LocalFolder {
  const LocalFolder({
    required this.path,
    required this.name,
    required this.trackCount,
  });

  final String path;
  final String name;
  final int trackCount;
}

class LocalScan {
  const LocalScan({
    required this.songs,
    required this.albums,
    required this.artists,
    this.folders = const [],
    this.meta = const {},
  });
  const LocalScan.empty()
    : songs = const [],
      albums = const [],
      artists = const [],
      folders = const [],
      meta = const {};

  final List<FeedItem> songs;
  final List<LocalCollection> albums;
  final List<LocalCollection> artists;

  final Map<String, LocalTrackMeta> meta;

  final List<LocalFolder> folders;
}

String folderLocation(String path) {
  var p = path;
  for (final prefix in const [
    '/storage/emulated/0',
    '/sdcard',
    '/mnt/sdcard',
  ]) {
    if (p == prefix) return 'Internal storage';
    if (p.startsWith('$prefix/')) {
      p = p.substring(prefix.length);
      break;
    }
  }
  final i = p.lastIndexOf('/');
  final parent = i <= 0 ? '' : p.substring(1, i);
  return parent.isEmpty ? 'Internal storage' : parent;
}

class LocalTrackMeta {
  const LocalTrackMeta({
    required this.disc,
    required this.track,
    required this.dateAdded,
    this.genre,
  });

  final int disc;
  final int track;
  final int dateAdded;
  final String? genre;

  factory LocalTrackMeta.fromRow(Map<Object?, Object?> row) {
    final raw = _intOf(row['track']);
    final genre = (row['genre'] ?? '').toString().trim();
    return LocalTrackMeta(
      disc: raw >= 1000 ? raw ~/ 1000 : 1,
      track: raw >= 1000 ? raw % 1000 : raw,
      dateAdded: _intOf(row['dateAdded']),
      genre: genre.isEmpty ? null : genre,
    );
  }

  static int _intOf(Object? v) =>
      v is int ? v : int.tryParse((v ?? '').toString()) ?? 0;
}

class FolderRules {
  const FolderRules({
    this.defaultIncluded = true,
    this.overrides = const <String, bool>{},
  });

  final bool defaultIncluded;
  final Map<String, bool> overrides;

  bool get isDefault => defaultIncluded && overrides.isEmpty;

  bool allows(String folder) => _resolve(folder);

  bool inherited(String folder) => _resolve(_parent(folder));

  bool _resolve(String? from) {
    var p = from;
    while (p != null && p.isNotEmpty) {
      final rule = overrides[p];
      if (rule != null) return rule;
      p = _parent(p);
    }
    return defaultIncluded;
  }

  static String? _parent(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? null : path.substring(0, i);
  }

  FolderRules set(String folder, {required bool included}) {
    final next = {...overrides};
    if (included == inherited(folder)) {
      next.remove(folder);
    } else {
      next[folder] = included;
    }
    return FolderRules(defaultIncluded: defaultIncluded, overrides: next);
  }

  FolderRules withDefault({required bool included}) =>
      FolderRules(defaultIncluded: included, overrides: overrides);

  bool sameAs(FolderRules other) {
    if (defaultIncluded != other.defaultIncluded) return false;
    if (overrides.length != other.overrides.length) return false;
    for (final e in overrides.entries) {
      if (other.overrides[e.key] != e.value) return false;
    }
    return true;
  }

  List<String> encode() => [
    defaultIncluded ? 'default+' : 'default-',
    for (final e in overrides.entries) '${e.value ? '+' : '-'}${e.key}',
  ];

  static FolderRules decode(Iterable<String> raw) {
    var byDefault = true;
    final overrides = <String, bool>{};
    for (final line in raw) {
      if (line == 'default+') {
        byDefault = true;
      } else if (line == 'default-') {
        byDefault = false;
      } else if (line.length > 2 && (line[0] == '+' || line[0] == '-')) {
        overrides[line.substring(1)] = line[0] == '+';
      }
    }
    return FolderRules(defaultIncluded: byDefault, overrides: overrides);
  }
}

String folderNameOf(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? path : path.substring(i + 1);
}

String folderOf(String path) {
  final i = path.lastIndexOf('/');
  return i <= 0 ? '' : path.substring(0, i);
}

const String kLocalSource = 'local';

class LocalMediaChannel {
  LocalMediaChannel._();
  static final LocalMediaChannel instance = LocalMediaChannel._();

  void onLibraryChanged(void Function() handler) {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'libraryChanged') handler();
    });
  }

  static const MethodChannel _channel = MethodChannel(
    'codes.afk.sunoh/localmedia',
  );

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  Future<LocalScan> scan({FolderRules rules = const FolderRules()}) async {
    if (!_supported) return const LocalScan.empty();
    try {
      final raw = await _channel.invokeListMethod<Object?>('scan');
      if (raw == null) return const LocalScan.empty();
      return _group(raw, rules);
    } on PlatformException catch (e) {
      debugPrint('[local] scan failed: ${e.message}');
      return const LocalScan.empty();
    } catch (e) {
      debugPrint('[local] scan error: $e');
      return const LocalScan.empty();
    }
  }

  static LocalScan _group(List<Object?> rows, FolderRules rules) {
    final songs = <FeedItem>[];
    final albums = <String, List<FeedItem>>{};
    final albumNames = <String, String>{};
    final albumArtistSets = <String, Set<String>>{};
    final artists = <String, List<FeedItem>>{};
    final artistNames = <String, String>{};
    final folderCounts = <String, int>{};
    final meta = <String, LocalTrackMeta>{};

    for (final row in rows) {
      if (row is! Map) continue;
      final r = row.cast<Object?, Object?>();
      final song = _toFeedItem(r);
      if (song == null) continue;

      final folder = folderOf(song.url ?? '');
      if (folder.isNotEmpty) {
        folderCounts[folder] = (folderCounts[folder] ?? 0) + 1;
      }
      if (!rules.allows(folder)) continue;

      songs.add(song);
      meta[song.id] = LocalTrackMeta.fromRow(r);

      final artist = _clean((r['artist'] ?? '').toString());
      final album = _clean((r['album'] ?? '').toString());

      if (album != null) {
        final key = (r['albumId'] ?? '').toString();
        if (key.isNotEmpty && key != '0') {
          albums
              .putIfAbsent(key, () {
                albumNames[key] = album;
                return <FeedItem>[];
              })
              .add(song);
          albumArtistSets.putIfAbsent(key, () => <String>{}).add(artist ?? '');
        }
      }

      if (artist != null) {
        final key = artist.toLowerCase();
        artists
            .putIfAbsent(key, () {
              artistNames[key] = artist;
              return <FeedItem>[];
            })
            .add(song);
      }
    }

    debugPrint(
      '[local] scanned ${songs.length} tracks, '
      '${albums.length} albums, ${artists.length} artists, '
      '${folderCounts.length} folders '
      '(${rules.isDefault ? 'all' : '${rules.overrides.length} rule(s), '
                'default ${rules.defaultIncluded ? 'in' : 'out'}'})',
    );
    return LocalScan(
      meta: meta,
      songs: songs,
      albums: [
        for (final e in albums.entries)
          LocalCollection(
            id: e.key,
            name: albumNames[e.key] ?? '',
            subtitle: _albumArtist(albumArtistSets[e.key]),
            songs: sortAlbumTracks(e.value, meta),
          ),
      ],
      artists: [
        for (final e in artists.entries)
          LocalCollection(
            id: e.key,
            name: artistNames[e.key] ?? '',
            subtitle: '${e.value.length} songs',
            songs: e.value,
          ),
      ],
      folders: _foldersFrom(folderCounts),
    );
  }

  static List<LocalFolder> _foldersFrom(Map<String, int> counts) {
    final out = [
      for (final e in counts.entries)
        LocalFolder(
          path: e.key,
          name: e.key.substring(e.key.lastIndexOf('/') + 1),
          trackCount: e.value,
        ),
    ]..sort((a, b) => b.trackCount.compareTo(a.trackCount));
    return out;
  }

  static String? _albumArtist(Set<String>? artists) {
    final named = (artists ?? const <String>{})
        .where((a) => a.isNotEmpty)
        .toList();
    if (named.isEmpty) return null;
    return named.length == 1 ? named.first : 'Various artists';
  }

  static FeedItem? _toFeedItem(Map<Object?, Object?> row) {
    final id = row['id']?.toString();
    final path = row['path']?.toString();
    if (id == null || id.isEmpty || path == null || path.isEmpty) return null;

    final artist = (row['artist'] ?? '').toString().trim();
    final album = (row['album'] ?? '').toString().trim();
    final artPath = row['artPath']?.toString();
    final duration = (row['durationSec'] as num?)?.toInt() ?? 0;

    return FeedItem(
      id: id,
      title: (row['title'] ?? 'Unknown').toString(),
      type: 'song',
      source: kLocalSource,
      url: path,
      image: [
        if (artPath != null && artPath.isNotEmpty)
          ApiImage(quality: 'high', link: artPath),
      ],
      subtitle: _subtitleFor(artist, album),
      duration: duration > 0 ? duration.toString() : null,
      artists: artist.isEmpty
          ? null
          : [
              ApiArtistRef(
                id: (row['artistId'] ?? '').toString(),
                name: artist,
              ),
            ],
      releaseDate: _yearOf(row['year']),
    );
  }

  static String? _subtitleFor(String artist, String album) {
    final a = _clean(artist);
    final b = _clean(album);
    if (a != null && b != null) return '$a · $b';
    return a ?? b;
  }

  static String? _clean(String value) {
    final v = value.trim();
    if (v.isEmpty || v == '<unknown>') return null;
    return v;
  }

  static String? _yearOf(Object? raw) {
    final year = (raw as num?)?.toInt() ?? 0;
    return year > 0 ? year.toString() : null;
  }
}
