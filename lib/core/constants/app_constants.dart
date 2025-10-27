/// Constantes de la aplicación
class AppConstants {
  // App Info
  static const String appName = 'Sinapsis';
  static const String appVersion = '1.0.0';

  // Database
  static const String dbName = 'sinapsis.db';
  static const int dbVersion = 1;

  // Pagination
  static const int defaultPageSize = 20;

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration cacheTimeout = Duration(hours: 1);

  // Storage Keys
  static const String userKey = 'user';
  static const String tokenKey = 'token';
  static const String themeKey = 'theme';
  static const String languageKey = 'language';

  // Share Codes
  static const int shareCodeLength = 6;

  // Study Settings
  static const int defaultCardsPerSession = 20;
  static const int easyInterval = 4; // días
  static const int mediumInterval = 1; // días
  static const int hardInterval = 10; // minutos
}
