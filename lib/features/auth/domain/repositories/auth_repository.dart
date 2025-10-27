import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user.dart';

/// Repositorio de autenticación (interfaz)
abstract class AuthRepository {
  /// Login con email y contraseña
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  });

  /// Registro con email y contraseña
  Future<Either<Failure, User>> register({
    required String email,
    required String password,
    String? name,
  });

  /// Logout
  Future<Either<Failure, void>> logout();

  /// Obtener usuario actual
  Future<Either<Failure, User?>> getCurrentUser();

  /// Verificar si está autenticado
  Future<bool> isAuthenticated();

  /// Restablecer contraseña
  Future<Either<Failure, void>> resetPassword({
    required String email,
  });
}
