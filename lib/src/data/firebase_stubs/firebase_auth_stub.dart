import 'dart:async';

import 'package:project/src/domain/entities/auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

abstract class AuthGateway {
  AuthUser? get currentUser;

  Future<AuthUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();
}

class FirebaseAuthStub implements AuthGateway {
  final Map<String, _CredentialRecord> _records = {};
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final normalized = email.trim().toLowerCase();
    final record = _records[normalized];
    if (record == null || record.password != password) {
      throw const AuthException('Неверный email или пароль.');
    }

    _currentUser = AuthUser(
      id: record.userId,
      email: normalized,
      displayName: record.displayName,
    );
    return _currentUser!;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));

    final normalized = email.trim().toLowerCase();
    if (_records.containsKey(normalized)) {
      throw const AuthException('Пользователь с таким email уже существует.');
    }
    if (password.length < 6) {
      throw const AuthException('Минимальная длина пароля: 6 символов.');
    }

    final created = AuthUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: normalized,
      displayName: displayName.trim().isEmpty ? 'Пользователь' : displayName,
    );
    _records[normalized] = _CredentialRecord(
      userId: created.id,
      displayName: created.displayName,
      password: password,
    );
    _currentUser = created;
    return created;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _currentUser = null;
  }
}

class _CredentialRecord {
  const _CredentialRecord({
    required this.userId,
    required this.displayName,
    required this.password,
  });

  final String userId;
  final String displayName;
  final String password;
}
