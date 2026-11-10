import 'dart:async';
import 'package:flutter/foundation.dart';

class UrlRefreshScheduler {
  UrlRefreshScheduler({required this.refresh});

  final Future<void> Function() refresh;

  Timer? _timer;
  String? _scheduledForSongId;
  DateTime? _scheduledFor;
  DateTime? _lastRefreshAt;

  static const _throttle = Duration(minutes: 2);

  bool get throttled {
    final last = _lastRefreshAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _throttle;
  }

  String? get scheduledForSongId => _scheduledForSongId;
  DateTime? get scheduledFor => _scheduledFor;

  bool isPastSafetyFor(
    String songId, {
    Duration withinWindow = const Duration(seconds: 15),
  }) {
    if (_scheduledForSongId != songId) return false;
    final at = _scheduledFor;
    if (at == null) return false;
    return DateTime.now().isAfter(at.subtract(withinWindow));
  }

  void schedule({
    required String songId,
    required String resolvedUrl,
    Duration safetyMargin = const Duration(minutes: 5),
    Duration fallbackTtl = const Duration(minutes: 45),
    Duration minLeadBeforeExpiry = const Duration(seconds: 25),
  }) {
    _timer?.cancel();
    _timer = null;

    final expiry = parseExpiry(resolvedUrl);
    final now = DateTime.now();
    final refreshAt = expiry != null
        ? expiry.subtract(safetyMargin)
        : now.add(fallbackTtl);
    final delay = refreshAt.difference(now);

    if (delay.inSeconds < 30) {
      Duration deferral;
      if (expiry != null) {
        final leadAt = expiry.subtract(minLeadBeforeExpiry);
        final leadDelay = leadAt.difference(now);
        deferral = leadDelay > const Duration(seconds: 5)
            ? leadDelay
            : const Duration(seconds: 5);
      } else {
        deferral = const Duration(seconds: 30);
      }
      _scheduledForSongId = songId;
      _scheduledFor = now.add(deferral);
      _timer = Timer(deferral, _fire);
      debugPrint(
        '[url-refresh] $songId past safety; '
        'deferred ${deferral.inSeconds}s '
        '(expiry=${expiry?.toIso8601String() ?? 'unparsed'})',
      );
      return;
    }

    _scheduledForSongId = songId;
    _scheduledFor = refreshAt;
    _timer = Timer(delay, _fire);
    debugPrint(
      '[url-refresh] $songId scheduled in ${delay.inMinutes} min '
      '(expiry=${expiry?.toIso8601String() ?? 'unparsed'})',
    );
  }

  void cancel() {
    if (_timer != null) {
      debugPrint('[url-refresh] cancel ${_scheduledForSongId ?? '?'}');
    }
    _timer?.cancel();
    _timer = null;
    _scheduledForSongId = null;
    _scheduledFor = null;
  }

  void dispose() => cancel();

  Future<void> triggerRefresh({required String reason}) async {
    if (throttled) {
      debugPrint('[url-refresh] throttled ($reason); skip');
      return;
    }
    _lastRefreshAt = DateTime.now();
    debugPrint('[url-refresh] firing ($reason)');
    try {
      await refresh();
    } catch (e) {
      debugPrint('[url-refresh] refresh failed: $e');
    }
  }

  void _fire() {
    _timer = null;
    _scheduledFor = null;
    _scheduledForSongId = null;
    unawaited(triggerRefresh(reason: 'pre-emptive timer'));
  }

  static DateTime? expiryFromNumber(Object? value) {
    final n = value is int
        ? value
        : value is num
        ? value.toInt()
        : int.tryParse('${value ?? ''}');
    if (n == null) return null;
    if (n >= 1000000000000) return DateTime.fromMillisecondsSinceEpoch(n);
    if (n >= 1000000000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
    if (n > 0 && n < 86400 * 7) {
      return DateTime.now().add(Duration(seconds: n));
    }
    return null;
  }

  static DateTime? parseExpiry(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    for (final key in const [
      'expires',
      'expire',
      'e',
      'oe',
      'exp',
      'ttl',
      'etsp',
    ]) {
      final raw = uri.queryParameters[key];
      if (raw == null || raw.isEmpty) continue;
      final n = int.tryParse(raw);
      if (n == null) continue;
      if (n >= 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n);
      }
      if (n >= 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
      if (n > 0 && n < 86400 * 7) {
        return DateTime.now().add(Duration(seconds: n));
      }
    }
    return null;
  }
}
