import 'package:project/src/data/firebase_stubs/firebase_auth_stub.dart';
import 'package:project/src/domain/entities/auth_user.dart';
import 'package:project/src/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._gateway);

  final AuthGateway _gateway;

  @override
  AuthUser? get currentUser => _gateway.currentUser;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) {
    return _gateway.signIn(email: email, password: password);
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _gateway.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  @override
  Future<void> signOut() => _gateway.signOut();
}
