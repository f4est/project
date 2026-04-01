import 'package:project/src/domain/entities/auth_user.dart';

abstract class AuthRepository {
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
