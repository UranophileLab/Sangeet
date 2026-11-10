import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

const String _kUpdatesUrl = Env.updateManifest;

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.url,
    this.buildNumber,
    this.notes,
    this.apks = const <String, String>{},
  });
  final String version;
  final int? buildNumber;

  final String url;
  final String? notes;

  final Map<String, String> apks;

  factory UpdateInfo.fromJson(Map<String, dynamic> j) {
    final apksRaw = j['apks'];
    final apks = <String, String>{};
    if (apksRaw is Map) {
      for (final entry in apksRaw.entries) {
        final k = entry.key.toString();
        final v = entry.value;
        if (v is String && v.trim().isNotEmpty) {
          apks[k] = v.trim();
        }
      }
    }
    return UpdateInfo(
      version: (j['version'] ?? '').toString().trim(),
      buildNumber: j['buildNumber'] is num
          ? (j['buildNumber'] as num).toInt()
          : int.tryParse('${j['buildNumber'] ?? ''}'),
      url: (j['url'] ?? '').toString().trim(),
      notes: (j['notes'] as String?)?.trim(),
      apks: apks,
    );
  }

  bool isNewerThan(String current) {
    if (version.isEmpty || current.isEmpty) return false;
    final a = version.split('.');
    final b = current.split('.');
    for (var i = 0; i < a.length && i < b.length; i++) {
      final ai = int.tryParse(a[i]);
      final bi = int.tryParse(b[i]);
      if (ai != null && bi != null) {
        if (ai != bi) return ai > bi;
      } else {
        final cmp = a[i].compareTo(b[i]);
        if (cmp != 0) return cmp > 0;
      }
    }
    return a.length > b.length;
  }
}

class UpdatesClient {
  UpdatesClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {'Accept': 'application/json'},
              responseType: ResponseType.json,
            ),
          );
  final Dio _dio;

  Future<UpdateInfo?> fetch() async {
    try {
      final res = await _dio.get<dynamic>(_kUpdatesUrl);
      final data = res.data;
      if (data is! Map) return null;
      final info = UpdateInfo.fromJson(data.cast<String, dynamic>());
      if (info.version.isEmpty || info.url.isEmpty) return null;
      return info;
    } catch (e) {
      debugPrint('[updates] fetch failed: $e');
      return null;
    }
  }
}
