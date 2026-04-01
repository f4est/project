import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:project/src/data/firebase_stubs/firebase_auth_stub.dart';
import 'package:project/src/domain/entities/auth_user.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._auth);

  final fb.FirebaseAuth _auth;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    return _toAuthUser(user);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Не удалось получить пользователя после входа.');
      }
      return _toAuthUser(user);
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('Не удалось создать пользователя.');
      }

      final name = displayName.trim().isEmpty ? 'Пользователь' : displayName.trim();
      await user.updateDisplayName(name);
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw const AuthException('Не удалось обновить профиль пользователя.');
      }
      return _toAuthUser(refreshedUser);
    } on fb.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AuthUser _toAuthUser(fb.User user) {
    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'Пользователь',
    );
  }

  String _mapAuthError(fb.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Некорректный email.';
      case 'user-disabled':
        return 'Пользователь заблокирован.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный email или пароль.';
      case 'email-already-in-use':
        return 'Пользователь с таким email уже существует.';
      case 'weak-password':
        return 'Слишком слабый пароль.';
      case 'network-request-failed':
        return 'Проблема сети. Проверьте интернет.';
      default:
        return error.message ?? 'Ошибка авторизации.';
    }
  }
}
