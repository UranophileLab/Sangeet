import 'package:dio/dio.dart';

import '../../config/env.dart';

const Duration kLyricsTimeout = Duration(seconds: 6);

const String kLyricsAgent = 'sunoh/1.0 (${Env.webBase})';

final Dio _client = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: kLyricsTimeout,
    sendTimeout: kLyricsTimeout,
    headers: {'User-Agent': kLyricsAgent, 'Accept': 'application/json'},
    responseType: ResponseType.plain,
    validateStatus: (status) => status != null && status >= 200 && status < 300,
  ),
);

Future<String?> lyricsGet(String url, {Map<String, String>? headers}) async {
  try {
    final response = await _client.get<String>(
      url,
      options: headers == null ? null : Options(headers: headers),
    );
    return response.data;
  } on Object {
    return null;
  }
}

Future<String?> lyricsGetAuthorized(String url, String bearer) => lyricsGet(
  url,
  headers: {
    'Authorization': 'Bearer $bearer',
    'Origin': Env.appleMusicWebBase,
    'Referer': '${Env.appleMusicWebBase}/',
  },
);
