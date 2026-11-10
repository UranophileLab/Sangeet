class Env {
  const Env._();

  static const apiBase = String.fromEnvironment(
    'SUNOH_API_BASE',
    defaultValue: 'https://api.sunoh.online',
  );

  static const webBase = String.fromEnvironment(
    'SUNOH_WEB_BASE',
    defaultValue: 'https://sunoh.online',
  );

  static const updateManifest = String.fromEnvironment(
    'SUNOH_UPDATE_MANIFEST',
    defaultValue: 'https://sunoh.online/.well-known/sunoh-updates.json',
  );

  static const lrclibBase = String.fromEnvironment(
    'LRCLIB_BASE',
    defaultValue: 'https://lrclib.net',
  );

  static const betterLyricsBase = String.fromEnvironment(
    'BETTER_LYRICS_BASE',
    defaultValue: 'https://lyrics-api.boidu.dev/getLyrics',
  );

  static const lyricsPlusMirrors = String.fromEnvironment(
    'LYRICS_PLUS_MIRRORS',
    defaultValue:
        'https://lyricsplus.prjktla.my.id,https://lyricsplus.atomix.one,https://lyricsplus.binimum.org,https://lyricsplus.prjktla.workers.dev,https://lyricsplus-seven.vercel.app,https://lyrics-plus-backend.vercel.app',
  );

  static const paxsenixBase = String.fromEnvironment(
    'PAXSENIX_BASE',
    defaultValue: 'https://lyrics.paxsenix.org',
  );

  static const appleMusicApiBase = String.fromEnvironment(
    'APPLE_MUSIC_API_BASE',
    defaultValue: 'https://amp-api.music.apple.com/v1/catalog/us',
  );

  static const appleMusicWebBase = String.fromEnvironment(
    'APPLE_MUSIC_WEB_BASE',
    defaultValue: 'https://music.apple.com',
  );

  static const simpMusicLyricsBase = String.fromEnvironment(
    'SIMPMUSIC_LYRICS_BASE',
    defaultValue: 'https://api-lyrics.simpmusic.org/v1',
  );

  static const musixmatchBase = String.fromEnvironment(
    'MUSIXMATCH_BASE',
    defaultValue: 'https://apic.musixmatch.com/ws/1.1',
  );

  static const musixmatchSecret = String.fromEnvironment('MUSIXMATCH_SECRET');

  static const sponsorBlockBase = String.fromEnvironment(
    'SPONSORBLOCK_BASE',
    defaultValue: 'https://sponsor.ajay.app/api/skipSegments',
  );

  static const geoIpBase = String.fromEnvironment(
    'GEOIP_BASE',
    defaultValue: 'https://ipwho.is/',
  );

  static const ytMusicBase = String.fromEnvironment(
    'YTMUSIC_BASE',
    defaultValue: 'https://music.youtube.com/youtubei/v1',
  );

  static List<String> get missing => {
    'SUNOH_API_BASE': apiBase,
    'SUNOH_WEB_BASE': webBase,
    'SUNOH_UPDATE_MANIFEST': updateManifest,
    'LRCLIB_BASE': lrclibBase,
    'BETTER_LYRICS_BASE': betterLyricsBase,
    'LYRICS_PLUS_MIRRORS': lyricsPlusMirrors,
    'PAXSENIX_BASE': paxsenixBase,
    'APPLE_MUSIC_API_BASE': appleMusicApiBase,
    'APPLE_MUSIC_WEB_BASE': appleMusicWebBase,
    'SIMPMUSIC_LYRICS_BASE': simpMusicLyricsBase,
    'MUSIXMATCH_BASE': musixmatchBase,
    'MUSIXMATCH_SECRET': musixmatchSecret,
    'SPONSORBLOCK_BASE': sponsorBlockBase,
    'GEOIP_BASE': geoIpBase,
    'YTMUSIC_BASE': ytMusicBase,
  }.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
}
