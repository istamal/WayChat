import 'dart:io';

import '../app_config.dart';

class NetworkUtils {
  static String get supabaseHost => AppConfig.supabaseHostRequired;

  static Future<bool> canResolveSupabase({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final result = await InternetAddress.lookup(
        supabaseHost,
      ).timeout(timeout);
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static bool isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('authretryablefetchexception') ||
        message.contains('clientexception');
  }
}
