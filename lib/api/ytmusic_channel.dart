import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class YtMusicStream {
  const YtMusicStream({
    required this.url,
    required this.headers,
    this.itag,
    this.mimeType,
    this.bitrate,
    this.contentLength,
    this.loudnessDb,
    this.clientName,
    this.expiresAt,
    this.requireBoundedRange = false,
    this.rangeChunkSizeBytes = 0,
    this.useRangeChunks = false,
  });

  final String url;
  final Map<String, String> headers;

  final int? itag;
  final String? mimeType;
  final int? bitrate;
  final int? contentLength;

  final double? loudnessDb;

  final String? clientName;

  final DateTime? expiresAt;

  final bool requireBoundedRange;
  final int rangeChunkSizeBytes;
  final bool useRangeChunks;

  static YtMusicStream? fromMap(Map<Object?, Object?>? m) {
    if (m == null) return null;
    final url = m['url'] as String?;
    if (url == null || url.isEmpty) return null;
    final rawHeaders = m['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      rawHeaders.forEach((k, v) {
        if (k != null && v != null) headers[k.toString()] = v.toString();
      });
    }
    final expiresMs = (m['expiresAtMs'] as num?)?.toInt();
    return YtMusicStream(
      url: url,
      headers: headers,
      itag: (m['itag'] as num?)?.toInt(),
      mimeType: m['mimeType'] as String?,
      bitrate: (m['bitrate'] as num?)?.toInt(),
      contentLength: (m['contentLength'] as num?)?.toInt(),
      loudnessDb: (m['loudnessDb'] as num?)?.toDouble(),
      clientName: m['clientName'] as String?,
      expiresAt: expiresMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresMs),
      requireBoundedRange: m['requireBoundedRange'] as bool? ?? false,
      rangeChunkSizeBytes: (m['rangeChunkSizeBytes'] as num?)?.toInt() ?? 0,
      useRangeChunks: m['useRangeChunks'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'YtMusicStream(itag: $itag, ${bitrate ?? '?'}bps, client: $clientName, '
      'expires: $expiresAt)';
}

class YtMusicChannel {
  YtMusicChannel._();
  static final YtMusicChannel instance = YtMusicChannel._();

  static const MethodChannel _channel = MethodChannel(
    'codes.afk.sunoh/ytmusic',
  );

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  Future<void> prewarm() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('prewarm');
      print('[ytmusic] prewarm complete');
    } catch (e) {
      print('[ytmusic] prewarm failed (non-fatal): $e');
    }
  }

  Future<YtMusicStream?> resolve(
    String videoId, {
    String quality = 'auto',
  }) async {
    if (!_supported || videoId.isEmpty) return null;
    try {
      final res = await _channel.invokeMethod<Map<Object?, Object?>>(
        'resolve',
        {'videoId': videoId, 'quality': quality},
      );
      final stream = YtMusicStream.fromMap(res);
      print('[ytmusic] resolved $videoId -> $stream');
      return stream;
    } on PlatformException catch (e) {
      print('[ytmusic] resolve failed for $videoId: ${e.message}');
      return null;
    } catch (e) {
      print('[ytmusic] resolve error for $videoId: $e');
      return null;
    }
  }
}
