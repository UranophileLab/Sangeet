import 'dto.dart';
import 'local_media_channel.dart';

enum LocalSort { dateAdded, title, artist, album, duration, year }

extension LocalSortLabel on LocalSort {
  String get label => switch (this) {
    LocalSort.dateAdded => 'Date added',
    LocalSort.title => 'Title',
    LocalSort.artist => 'Artist',
    LocalSort.album => 'Album',
    LocalSort.duration => 'Duration',
    LocalSort.year => 'Year',
  };

  String get ascendingLabel => switch (this) {
    LocalSort.dateAdded => 'Oldest first',
    LocalSort.duration => 'Shortest first',
    LocalSort.year => 'Oldest first',
    _ => 'A to Z',
  };

  String get descendingLabel => switch (this) {
    LocalSort.dateAdded => 'Newest first',
    LocalSort.duration => 'Longest first',
    LocalSort.year => 'Newest first',
    _ => 'Z to A',
  };

  String get key => name;

  static LocalSort fromKey(String? key) => LocalSort.values.firstWhere(
    (s) => s.name == key,
    orElse: () => LocalSort.dateAdded,
  );
}

List<FeedItem> sortLocalSongs(
  List<FeedItem> songs,
  Map<String, LocalTrackMeta> meta, {
  required LocalSort by,
  required bool ascending,
}) {
  int compare(FeedItem a, FeedItem b) {
    final result = switch (by) {
      LocalSort.title => _text(a.title, b.title),
      LocalSort.artist => _text(_artistOf(a), _artistOf(b)),
      LocalSort.album => _text(_albumOf(a), _albumOf(b)),
      LocalSort.duration => _int(a.duration, b.duration),
      LocalSort.year => _int(a.releaseDate, b.releaseDate),
      LocalSort.dateAdded => (meta[a.id]?.dateAdded ?? 0).compareTo(
        meta[b.id]?.dateAdded ?? 0,
      ),
    };
    if (result != 0) return result;
    return _text(a.title, b.title);
  }

  final out = [...songs]..sort(compare);
  return ascending ? out : out.reversed.toList();
}

List<FeedItem> sortAlbumTracks(
  List<FeedItem> songs,
  Map<String, LocalTrackMeta> meta,
) {
  final out = [...songs];
  out.sort((a, b) {
    final ma = meta[a.id];
    final mb = meta[b.id];
    final disc = (ma?.disc ?? 1).compareTo(mb?.disc ?? 1);
    if (disc != 0) return disc;
    final ta = (ma?.track ?? 0) == 0 ? 1 << 20 : ma!.track;
    final tb = (mb?.track ?? 0) == 0 ? 1 << 20 : mb!.track;
    if (ta != tb) return ta.compareTo(tb);
    return _text(a.title, b.title);
  });
  return out;
}

int _text(String a, String b) => _sortKey(a).compareTo(_sortKey(b));

String _sortKey(String raw) {
  var s = raw.trim().toLowerCase();
  for (final article in const ['the ', 'a ', 'an ']) {
    if (s.startsWith(article)) {
      s = s.substring(article.length);
      break;
    }
  }
  return s;
}

int _int(String? a, String? b) =>
    (int.tryParse(a ?? '') ?? 0).compareTo(int.tryParse(b ?? '') ?? 0);

String _artistOf(FeedItem s) {
  final artists = s.artists;
  if (artists != null && artists.isNotEmpty) return artists.first.name;
  return s.subtitle ?? '';
}

String _albumOf(FeedItem s) {
  final sub = s.subtitle ?? '';
  final i = sub.indexOf(' · ');
  return i >= 0 ? sub.substring(i + 3) : sub;
}
