enum LyricsSource {
  betterLyrics('BetterLyrics', wordSynced: true),

  paxSenix('PaxSenix', wordSynced: true),

  musixmatch('Musixmatch', wordSynced: false),

  lyricsPlus('LyricsPlus', wordSynced: true),

  lrcLib('LRCLIB', wordSynced: false),

  simpMusic('SimpMusic', wordSynced: true);

  const LyricsSource(this.label, {required this.wordSynced});

  final String label;

  final bool wordSynced;
}
