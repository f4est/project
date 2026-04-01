import 'package:project/src/domain/entities/auth_user.dart';
import 'package:project/src/domain/repositories/auth_repository.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _repository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }
}
