import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => _env('SUPABASE_URL');
  static String get supabaseAnonKey => _env('SUPABASE_ANON_KEY');
  static String get supabaseHost => _env('SUPABASE_HOST');

  static String get supabaseUrlRequired =>
      _required(supabaseUrl, 'SUPABASE_URL');
  static String get supabaseAnonKeyRequired =>
      _required(supabaseAnonKey, 'SUPABASE_ANON_KEY');
  static String get supabaseHostRequired =>
      _required(supabaseHost, 'SUPABASE_HOST');

  static String get _firebaseApiKey => _env('FIREBASE_API_KEY');
  static String get _firebaseApiKeyWeb => _env('FIREBASE_WEB_API_KEY');
  static String get _firebaseApiKeyAndroid => _env('FIREBASE_ANDROID_API_KEY');
  static String get _firebaseApiKeyIos => _env('FIREBASE_IOS_API_KEY');
  static String get _firebaseApiKeyMacos => _env('FIREBASE_MACOS_API_KEY');
  static String get _firebaseApiKeyWindows => _env('FIREBASE_WINDOWS_API_KEY');

  static String get _firebaseAppId => _env('FIREBASE_APP_ID');
  static String get _firebaseAppIdWeb => _env('FIREBASE_WEB_APP_ID');
  static String get _firebaseAppIdAndroid => _env('FIREBASE_ANDROID_APP_ID');
  static String get _firebaseAppIdIos => _env('FIREBASE_IOS_APP_ID');
  static String get _firebaseAppIdMacos => _env('FIREBASE_MACOS_APP_ID');
  static String get _firebaseAppIdWindows => _env('FIREBASE_WINDOWS_APP_ID');

  static String get _firebaseMessagingSenderId =>
      _env('FIREBASE_MESSAGING_SENDER_ID');
  static String get _firebaseProjectId => _env('FIREBASE_PROJECT_ID');
  static String get _firebaseAuthDomain => _env('FIREBASE_AUTH_DOMAIN');
  static String get _firebaseStorageBucket => _env('FIREBASE_STORAGE_BUCKET');
  static String get _firebaseMeasurementId => _env('FIREBASE_MEASUREMENT_ID');
  static String get _firebaseIosBundleId => _env('FIREBASE_IOS_BUNDLE_ID');

  static String get firebaseApiKeyWeb =>
      _selectWebValue(generic: _firebaseApiKey, web: _firebaseApiKeyWeb);

  static String get firebaseAppIdWeb =>
      _selectWebValue(generic: _firebaseAppId, web: _firebaseAppIdWeb);

  static String firebaseApiKeyFor(TargetPlatform platform) =>
      _selectPlatformValue(
        platform: platform,
        generic: _firebaseApiKey,
        web: _firebaseApiKeyWeb,
        android: _firebaseApiKeyAndroid,
        ios: _firebaseApiKeyIos,
        macos: _firebaseApiKeyMacos,
        windows: _firebaseApiKeyWindows,
      );

  static String firebaseAppIdFor(TargetPlatform platform) => _selectPlatformValue(
        platform: platform,
        generic: _firebaseAppId,
        web: _firebaseAppIdWeb,
        android: _firebaseAppIdAndroid,
        ios: _firebaseAppIdIos,
        macos: _firebaseAppIdMacos,
        windows: _firebaseAppIdWindows,
      );

  static String get firebaseMessagingSenderId =>
      _required(_firebaseMessagingSenderId, 'FIREBASE_MESSAGING_SENDER_ID');

  static String get firebaseProjectId =>
      _required(_firebaseProjectId, 'FIREBASE_PROJECT_ID');

  static String? get firebaseAuthDomain =>
      _firebaseAuthDomain.isEmpty ? null : _firebaseAuthDomain;

  static String? get firebaseStorageBucket =>
      _firebaseStorageBucket.isEmpty ? null : _firebaseStorageBucket;

  static String? get firebaseMeasurementId =>
      _firebaseMeasurementId.isEmpty ? null : _firebaseMeasurementId;

  static String? get firebaseIosBundleId =>
      _firebaseIosBundleId.isEmpty ? null : _firebaseIosBundleId;

  static String _selectPlatformValue({
    required TargetPlatform platform,
    required String generic,
    String? web,
    String? android,
    String? ios,
    String? macos,
    String? windows,
  }) {
    String candidate = generic;
    switch (platform) {
      case TargetPlatform.android:
        candidate = (android?.isNotEmpty ?? false) ? android! : generic;
        break;
      case TargetPlatform.iOS:
        candidate = (ios?.isNotEmpty ?? false) ? ios! : generic;
        break;
      case TargetPlatform.macOS:
        candidate = (macos?.isNotEmpty ?? false) ? macos! : generic;
        break;
      case TargetPlatform.windows:
        candidate = (windows?.isNotEmpty ?? false) ? windows! : generic;
        break;
      case TargetPlatform.linux:
        candidate = generic;
        break;
      case TargetPlatform.fuchsia:
        candidate = generic;
        break;
    }
    if (candidate.isEmpty) {
      throw StateError('Missing Firebase config for ${platform.name}');
    }
    return candidate;
  }

  static String _required(String value, String name) {
    if (value.isEmpty) {
      throw StateError('Missing required env: $name');
    }
    return value;
  }

  static String _selectWebValue({
    required String generic,
    required String web,
  }) {
    final candidate = web.isNotEmpty ? web : generic;
    if (candidate.isEmpty) {
      throw StateError('Missing Firebase web config');
    }
    return candidate;
  }

  static String _env(String name) {
    switch (name) {
      case 'SUPABASE_URL':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('SUPABASE_URL'),
          'SUPABASE_URL',
        );
      case 'SUPABASE_ANON_KEY':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('SUPABASE_ANON_KEY'),
          'SUPABASE_ANON_KEY',
        );
      case 'SUPABASE_HOST':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('SUPABASE_HOST'),
          'SUPABASE_HOST',
        );
      case 'FIREBASE_API_KEY':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_API_KEY'),
          'FIREBASE_API_KEY',
        );
      case 'FIREBASE_WEB_API_KEY':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
          'FIREBASE_WEB_API_KEY',
        );
      case 'FIREBASE_ANDROID_API_KEY':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
          'FIREBASE_ANDROID_API_KEY',
        );
      case 'FIREBASE_IOS_API_KEY':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
          'FIREBASE_IOS_API_KEY',
        );
      case 'FIREBASE_MACOS_API_KEY':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_MACOS_API_KEY'),
          'FIREBASE_MACOS_API_KEY',
        );
      case 'FIREBASE_WINDOWS_API_KEY':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_WINDOWS_API_KEY'),
          'FIREBASE_WINDOWS_API_KEY',
        );
      case 'FIREBASE_APP_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_APP_ID'),
          'FIREBASE_APP_ID',
        );
      case 'FIREBASE_WEB_APP_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
          'FIREBASE_WEB_APP_ID',
        );
      case 'FIREBASE_ANDROID_APP_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
          'FIREBASE_ANDROID_APP_ID',
        );
      case 'FIREBASE_IOS_APP_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
          'FIREBASE_IOS_APP_ID',
        );
      case 'FIREBASE_MACOS_APP_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_MACOS_APP_ID'),
          'FIREBASE_MACOS_APP_ID',
        );
      case 'FIREBASE_WINDOWS_APP_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_WINDOWS_APP_ID'),
          'FIREBASE_WINDOWS_APP_ID',
        );
      case 'FIREBASE_MESSAGING_SENDER_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
          'FIREBASE_MESSAGING_SENDER_ID',
        );
      case 'FIREBASE_PROJECT_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_PROJECT_ID'),
          'FIREBASE_PROJECT_ID',
        );
      case 'FIREBASE_AUTH_DOMAIN':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
          'FIREBASE_AUTH_DOMAIN',
        );
      case 'FIREBASE_STORAGE_BUCKET':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
          'FIREBASE_STORAGE_BUCKET',
        );
      case 'FIREBASE_MEASUREMENT_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
          'FIREBASE_MEASUREMENT_ID',
        );
      case 'FIREBASE_IOS_BUNDLE_ID':
        return _fromDefineOrDotenv(
          const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
          'FIREBASE_IOS_BUNDLE_ID',
        );
      default:
        break;
    }
    return dotenv.env[name] ?? '';
  }

  static String _fromDefineOrDotenv(String fromDefine, String key) {
    if (fromDefine.isNotEmpty) return fromDefine;
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }
}
