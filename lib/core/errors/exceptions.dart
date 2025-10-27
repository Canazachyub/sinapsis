/// Excepción del servidor
class ServerException implements Exception {
  final String message;

  const ServerException([this.message = 'Error del servidor']);

  @override
  String toString() => 'ServerException: $message';
}

/// Excepción de caché
class CacheException implements Exception {
  final String message;

  const CacheException([this.message = 'Error de caché']);

  @override
  String toString() => 'CacheException: $message';
}

/// Excepción de red
class NetworkException implements Exception {
  final String message;

  const NetworkException([this.message = 'Error de conexión']);

  @override
  String toString() => 'NetworkException: $message';
}

/// Excepción de autenticación
class AuthException implements Exception {
  final String message;

  const AuthException([this.message = 'Error de autenticación']);

  @override
  String toString() => 'AuthException: $message';
}

/// Excepción de validación
class ValidationException implements Exception {
  final String message;

  const ValidationException([this.message = 'Error de validación']);

  @override
  String toString() => 'ValidationException: $message';
}
