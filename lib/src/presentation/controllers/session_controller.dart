import 'package:flutter/foundation.dart';
import 'package:project/src/domain/entities/auth_user.dart';
import 'package:project/src/domain/usecases/auth/sign_in_use_case.dart';
import 'package:project/src/domain/usecases/auth/sign_out_use_case.dart';
import 'package:project/src/domain/usecases/auth/sign_up_use_case.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required SignInUseCase signInUseCase,
    required SignUpUseCase signUpUseCase,
    required SignOutUseCase signOutUseCase,
    AuthUser? initialUser,
  })  : _signInUseCase = signInUseCase,
        _signUpUseCase = signUpUseCase,
        _signOutUseCase = signOutUseCase,
        _currentUser = initialUser;

  final SignInUseCase _signInUseCase;
  final SignUpUseCase _signUpUseCase;
  final SignOutUseCase _signOutUseCase;

  AuthUser? _currentUser;
  bool _isBusy = false;
  String? _errorMessage;

  AuthUser? get currentUser => _currentUser;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get isAuthorized => _currentUser != null;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return _runSessionOperation(() async {
      _currentUser = await _signInUseCase(email: email, password: password);
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _runSessionOperation(() async {
      _currentUser = await _signUpUseCase(
        email: email,
        password: password,
        displayName: displayName,
      );
    });
  }

  Future<void> signOut() async {
    _isBusy = true;
    notifyListeners();
    try {
      await _signOutUseCase();
      _currentUser = null;
      _errorMessage = null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _runSessionOperation(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
