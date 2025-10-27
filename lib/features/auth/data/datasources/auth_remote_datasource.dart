import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart' as app_exceptions;
import '../models/user_model.dart';

/// Data source remoto para autenticación
abstract class AuthRemoteDataSource {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> register({
    required String email,
    required String password,
    String? name,
  });
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<bool> isAuthenticated();
  Future<void> resetPassword({required String email});
}

/// Implementación con Supabase
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient client;

  AuthRemoteDataSourceImpl({required this.client});

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const app_exceptions.AuthException('Error al iniciar sesión');
      }

      return UserModel(
        id: response.user!.id,
        email: response.user!.email!,
        name: response.user!.userMetadata?['name'],
        avatarUrl: response.user!.userMetadata?['avatar_url'],
        createdAt: DateTime.parse(response.user!.createdAt),
      );
    } on app_exceptions.AuthException {
      rethrow;
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (name != null) 'name': name,
        },
      );

      if (response.user == null) {
        throw const app_exceptions.AuthException('Error al registrarse');
      }

      return UserModel(
        id: response.user!.id,
        email: response.user!.email!,
        name: response.user!.userMetadata?['name'],
        avatarUrl: response.user!.userMetadata?['avatar_url'],
        createdAt: DateTime.parse(response.user!.createdAt),
      );
    } on app_exceptions.AuthException {
      rethrow;
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = client.auth.currentUser;

      if (user == null) {
        return null;
      }

      return UserModel(
        id: user.id,
        email: user.email!,
        name: user.userMetadata?['name'],
        avatarUrl: user.userMetadata?['avatar_url'],
        createdAt: DateTime.parse(user.createdAt),
      );
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final user = client.auth.currentUser;
    return user != null;
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }
}
