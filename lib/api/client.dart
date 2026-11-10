import 'package:dio/dio.dart';

import '../config/env.dart';

class SunohApiEnv {
  static const baseUrl = Env.apiBase;
}

Dio buildSunohDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: SunohApiEnv.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );

  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (o) {
          // ignore: avoid_print
          print('[sunoh-api] $o');
        },
      ),
    );
    return true;
  }());

  return dio;
}
