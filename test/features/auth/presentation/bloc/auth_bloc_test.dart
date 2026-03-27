import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sinapsis/core/errors/failures.dart';
import 'package:sinapsis/features/auth/domain/entities/user.dart';
import 'package:sinapsis/features/auth/domain/usecases/login_usecase.dart';
import 'package:sinapsis/features/auth/domain/usecases/register_usecase.dart';
import 'package:sinapsis/features/auth/domain/usecases/logout_usecase.dart';
import 'package:sinapsis/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:sinapsis/features/auth/presentation/bloc/auth_bloc.dart';

@GenerateMocks([LoginUseCase, RegisterUseCase, LogoutUseCase, GetCurrentUserUseCase])
import 'auth_bloc_test.mocks.dart';

void main() {
  late AuthBloc bloc;
  late MockLoginUseCase mockLogin;
  late MockRegisterUseCase mockRegister;
  late MockLogoutUseCase mockLogout;
  late MockGetCurrentUserUseCase mockGetCurrentUser;

  final tUser = User(
    id: 'user-1',
    email: 'test@test.com',
    name: 'Test User',
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    mockLogin = MockLoginUseCase();
    mockRegister = MockRegisterUseCase();
    mockLogout = MockLogoutUseCase();
    mockGetCurrentUser = MockGetCurrentUserUseCase();
    bloc = AuthBloc(
      loginUseCase: mockLogin,
      registerUseCase: mockRegister,
      logoutUseCase: mockLogout,
      getCurrentUserUseCase: mockGetCurrentUser,
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be AuthInitial', () {
    expect(bloc.state, isA<AuthInitial>());
  });

  group('LoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] on successful login',
      build: () {
        when(mockLogin(email: 'test@test.com', password: 'password'))
            .thenAnswer((_) async => Right(tUser));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(
        email: 'test@test.com',
        password: 'password',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<Authenticated>().having((s) => s.user.email, 'email', 'test@test.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on failed login',
      build: () {
        when(mockLogin(email: 'test@test.com', password: 'wrong'))
            .thenAnswer((_) async => const Left(AuthFailure('Invalid credentials')));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(
        email: 'test@test.com',
        password: 'wrong',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having((s) => s.message, 'message', 'Invalid credentials'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on network failure',
      build: () {
        when(mockLogin(email: 'test@test.com', password: 'password'))
            .thenAnswer((_) async => const Left(NetworkFailure()));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(
        email: 'test@test.com',
        password: 'password',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>()
            .having((s) => s.message, 'message', 'Error de conexión'),
      ],
    );
  });

  group('RegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] on successful register',
      build: () {
        when(mockRegister(
          email: 'new@test.com',
          password: 'password',
          name: 'New User',
        )).thenAnswer((_) async => Right(tUser));
        return bloc;
      },
      act: (bloc) => bloc.add(const RegisterRequested(
        email: 'new@test.com',
        password: 'password',
        name: 'New User',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<Authenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on register failure',
      build: () {
        when(mockRegister(
          email: 'existing@test.com',
          password: 'password',
          name: null,
        )).thenAnswer(
            (_) async => const Left(AuthFailure('Email already registered')));
        return bloc;
      },
      act: (bloc) => bloc.add(const RegisterRequested(
        email: 'existing@test.com',
        password: 'password',
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );
  });

  group('LogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] on successful logout',
      build: () {
        when(mockLogout()).thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (bloc) => bloc.add(const LogoutRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<Unauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] on logout failure',
      build: () {
        when(mockLogout())
            .thenAnswer((_) async => const Left(AuthFailure('Logout failed')));
        return bloc;
      },
      act: (bloc) => bloc.add(const LogoutRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );
  });

  group('CheckAuthStatus', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] when user is cached',
      build: () {
        when(mockGetCurrentUser())
            .thenAnswer((_) async => Right(tUser));
        return bloc;
      },
      act: (bloc) => bloc.add(const CheckAuthStatus()),
      expect: () => [
        isA<AuthLoading>(),
        isA<Authenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] when no user cached',
      build: () {
        when(mockGetCurrentUser())
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (bloc) => bloc.add(const CheckAuthStatus()),
      expect: () => [
        isA<AuthLoading>(),
        isA<Unauthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] on failure (graceful degradation)',
      build: () {
        when(mockGetCurrentUser())
            .thenAnswer((_) async => const Left(CacheFailure('Error')));
        return bloc;
      },
      act: (bloc) => bloc.add(const CheckAuthStatus()),
      expect: () => [
        isA<AuthLoading>(),
        isA<Unauthenticated>(),
      ],
    );
  });

  group('AuthEvent equality', () {
    test('LoginRequested with same params are equal', () {
      const e1 = LoginRequested(email: 'a@b.c', password: 'p');
      const e2 = LoginRequested(email: 'a@b.c', password: 'p');
      expect(e1, equals(e2));
    });

    test('RegisterRequested props include name', () {
      const e = RegisterRequested(email: 'a@b.c', password: 'p', name: 'N');
      expect(e.props, ['a@b.c', 'p', 'N']);
    });
  });

  group('AuthState equality', () {
    test('Authenticated with same user are equal', () {
      final s1 = Authenticated(tUser);
      final s2 = Authenticated(tUser);
      expect(s1, equals(s2));
    });

    test('AuthError with same message are equal', () {
      const s1 = AuthError('err');
      const s2 = AuthError('err');
      expect(s1, equals(s2));
    });
  });
}
