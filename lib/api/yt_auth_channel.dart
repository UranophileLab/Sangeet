import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class YtAccount {
  const YtAccount({
    this.signedIn = false,
    this.name = '',
    this.visitorData = '',
  });

  final bool signedIn;

  final String name;

  final String visitorData;

  static const signedOut = YtAccount();
}

class YtAuthChannel {
  YtAuthChannel._();
  static final YtAuthChannel instance = YtAuthChannel._();

  static const MethodChannel _channel = MethodChannel('codes.afk.sunoh/ytauth');

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  Future<YtAccount> state() async {
    if (!_supported) return YtAccount.signedOut;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('state');
      if (raw == null) return YtAccount.signedOut;
      return YtAccount(
        signedIn: raw['signedIn'] == true,
        name: (raw['accountName'] ?? '').toString(),
        visitorData: (raw['visitorData'] ?? '').toString(),
      );
    } on PlatformException catch (e) {
      debugPrint('[ytauth] state failed: ${e.code}');
      return YtAccount.signedOut;
    }
  }

  Future<bool> signIn() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('signIn') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ytauth] signIn failed: ${e.code}');
      return false;
    }
  }

  Future<void> signOut() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('signOut');
    } on PlatformException catch (e) {
      debugPrint('[ytauth] signOut failed: ${e.code}');
    }
  }

  Future<Map<String, String>> headers() async {
    if (!_supported) return const {};
    try {
      final raw = await _channel.invokeMapMethod<String, String>('headers');
      return raw ?? const {};
    } on PlatformException catch (e) {
      debugPrint('[ytauth] headers failed: ${e.code}');
      return const {};
    }
  }

  Future<void> setAccountName(String name) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setAccountName', {'name': name});
    } on PlatformException catch (e) {
      debugPrint('[ytauth] setAccountName failed: ${e.code}');
    }
  }
}
