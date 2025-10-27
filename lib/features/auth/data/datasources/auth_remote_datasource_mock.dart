import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/errors/exceptions.dart' as app_exceptions;
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

/// Implementación MOCK de AuthRemoteDataSource (sin Supabase)
/// Usa SharedPreferences para simular un backend local
class AuthRemoteDataSourceMockImpl implements AuthRemoteDataSource {
  final SharedPreferences prefs;

  static const String _usersKey = 'MOCK_USERS';
  static const String _currentUserIdKey = 'MOCK_CURRENT_USER_ID';

  AuthRemoteDataSourceMockImpl({required this.prefs});

  // Obtener todos los usuarios registrados
  Map<String, dynamic> _getUsers() {
    final usersJson = prefs.getString(_usersKey);
    if (usersJson == null) return {};
    return json.decode(usersJson) as Map<String, dynamic>;
  }

  // Guardar usuarios
  Future<void> _saveUsers(Map<String, dynamic> users) async {
    await prefs.setString(_usersKey, json.encode(users));
  }

  // Generar ID único simple
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500)); // Simular latencia

      final users = _getUsers();

      // Buscar usuario por email
      final userEntry = users.entries.firstWhere(
        (entry) {
          final user = entry.value as Map<String, dynamic>;
          return user['email'] == email;
        },
        orElse: () => throw app_exceptions.AuthException('Usuario no encontrado'),
      );

      final userData = userEntry.value as Map<String, dynamic>;

      // Verificar contraseña
      if (userData['password'] != password) {
        throw const app_exceptions.AuthException('Contraseña incorrecta');
      }

      // Guardar sesión actual
      await prefs.setString(_currentUserIdKey, userEntry.key);

      return UserModel(
        id: userEntry.key,
        email: userData['email'],
        name: userData['name'],
        avatarUrl: userData['avatarUrl'],
        createdAt: DateTime.parse(userData['createdAt']),
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
      await Future.delayed(const Duration(milliseconds: 500)); // Simular latencia

      final users = _getUsers();

      // Verificar si el email ya existe
      final emailExists = users.values.any((user) {
        final userData = user as Map<String, dynamic>;
        return userData['email'] == email;
      });

      if (emailExists) {
        throw const app_exceptions.AuthException('El email ya está registrado');
      }

      // Crear nuevo usuario
      final userId = _generateId();
      final now = DateTime.now();

      final newUser = {
        'email': email,
        'password': password, // En producción NUNCA guardar así, pero es un mock
        'name': name,
        'avatarUrl': null,
        'createdAt': now.toIso8601String(),
      };

      users[userId] = newUser;
      await _saveUsers(users);

      // Guardar sesión actual
      await prefs.setString(_currentUserIdKey, userId);

      return UserModel(
        id: userId,
        email: email,
        name: name,
        avatarUrl: null,
        createdAt: now,
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
      await prefs.remove(_currentUserIdKey);
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final currentUserId = prefs.getString(_currentUserIdKey);
      if (currentUserId == null) {
        return null;
      }

      final users = _getUsers();
      final userData = users[currentUserId];

      if (userData == null) {
        return null;
      }

      final user = userData as Map<String, dynamic>;

      return UserModel(
        id: currentUserId,
        email: user['email'],
        name: user['name'],
        avatarUrl: user['avatarUrl'],
        createdAt: DateTime.parse(user['createdAt']),
      );
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final currentUserId = prefs.getString(_currentUserIdKey);
    return currentUserId != null;
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final users = _getUsers();

      // Verificar que el email existe
      final emailExists = users.values.any((user) {
        final userData = user as Map<String, dynamic>;
        return userData['email'] == email;
      });

      if (!emailExists) {
        throw const app_exceptions.AuthException('Email no encontrado');
      }

      // En un mock, simplemente simulamos que se envió el email
      // No hacemos nada realmente
    } catch (e) {
      throw app_exceptions.AuthException(e.toString());
    }
  }
}
