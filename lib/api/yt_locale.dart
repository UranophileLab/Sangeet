import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

@immutable
class YtLocale {
  const YtLocale({
    required this.country,
    required this.language,
    this.countryIsAuto = true,
    this.languageIsAuto = true,
  });

  final String country;
  final String language;
  final bool countryIsAuto;
  final bool languageIsAuto;

  static const fallback = YtLocale(country: 'IN', language: 'en');

  @override
  String toString() =>
      'YtLocale($country/$language, '
      'auto: country=$countryIsAuto language=$languageIsAuto)';

  @override
  bool operator ==(Object other) =>
      other is YtLocale &&
      other.country == country &&
      other.language == language &&
      other.countryIsAuto == countryIsAuto &&
      other.languageIsAuto == languageIsAuto;

  @override
  int get hashCode =>
      Object.hash(country, language, countryIsAuto, languageIsAuto);
}

const kYtRegions = <String, String>{
  'IN': 'India',
  'US': 'United States',
  'GB': 'United Kingdom',
  'CA': 'Canada',
  'AU': 'Australia',
  'DE': 'Germany',
  'FR': 'France',
  'JP': 'Japan',
  'KR': 'South Korea',
  'BR': 'Brazil',
  'MX': 'Mexico',
  'ID': 'Indonesia',
  'PK': 'Pakistan',
  'BD': 'Bangladesh',
  'AE': 'United Arab Emirates',
  'SG': 'Singapore',
  'NG': 'Nigeria',
  'ZA': 'South Africa',
};

const kYtLanguages = <String, String>{
  'en': 'English',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'ta': 'Tamil',
  'te': 'Telugu',
  'mr': 'Marathi',
  'gu': 'Gujarati',
  'kn': 'Kannada',
  'ml': 'Malayalam',
  'pa': 'Punjabi',
  'ur': 'Urdu',
  'es': 'Spanish',
  'pt': 'Portuguese',
  'fr': 'French',
  'de': 'German',
  'ja': 'Japanese',
  'ko': 'Korean',
  'id': 'Indonesian',
};

class YtLocaleResolver {
  YtLocaleResolver(this._dio);
  final Dio _dio;

  static const _kTtl = Duration(hours: 24);

  String? _cachedCountry;
  DateTime? _cachedAt;

  static String? deviceCountry() {
    final code = PlatformDispatcher.instance.locale.countryCode;
    return (code == null || code.isEmpty) ? null : code.toUpperCase();
  }

  static String? deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return (code.isEmpty) ? null : code.toLowerCase();
  }

  YtLocale resolve({String? countryOverride, String? languageOverride}) {
    final country = (countryOverride != null && countryOverride.isNotEmpty)
        ? countryOverride
        : (_freshCachedCountry() ??
              deviceCountry() ??
              YtLocale.fallback.country);
    final language = (languageOverride != null && languageOverride.isNotEmpty)
        ? languageOverride
        : (deviceLanguage() ?? YtLocale.fallback.language);
    return YtLocale(
      country: country,
      language: language,
      countryIsAuto: countryOverride == null || countryOverride.isEmpty,
      languageIsAuto: languageOverride == null || languageOverride.isEmpty,
    );
  }

  String? _freshCachedCountry() {
    final at = _cachedAt;
    if (_cachedCountry == null || at == null) return null;
    if (DateTime.now().difference(at) > _kTtl) return null;
    return _cachedCountry;
  }

  Future<String?> refreshFromIp() async {
    if (_freshCachedCountry() != null) return _cachedCountry;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        Env.geoIpBase,
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
      final code = res.data?['country_code'];
      if (code is String && code.length == 2) {
        _cachedCountry = code.toUpperCase();
        _cachedAt = DateTime.now();
        print('[yt-locale] region from IP: $_cachedCountry');
        return _cachedCountry;
      }
    } catch (e) {
      print('[yt-locale] IP lookup failed, staying on device locale: $e');
    }
    return null;
  }
}
