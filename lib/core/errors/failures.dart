import 'package:equatable/equatable.dart';

/// Clase base para fallos
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Fallo del servidor
class ServerFailure extends Failure {
  const ServerFailure([String message = 'Error del servidor']) : super(message);
}

/// Fallo de caché
class CacheFailure extends Failure {
  const CacheFailure([String message = 'Error de caché']) : super(message);
}

/// Fallo de red
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Error de conexión']) : super(message);
}

/// Fallo de autenticación
class AuthFailure extends Failure {
  const AuthFailure([String message = 'Error de autenticación']) : super(message);
}

/// Fallo de validación
class ValidationFailure extends Failure {
  const ValidationFailure([String message = 'Error de validación']) : super(message);
}

/// Fallo no encontrado
class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Recurso no encontrado']) : super(message);
}

/// Fallo de permisos
class PermissionFailure extends Failure {
  const PermissionFailure([String message = 'Permisos insuficientes']) : super(message);
}
