import 'package:flutter_test/flutter_test.dart';
import 'package:project/src/data/firebase_stubs/firebase_auth_stub.dart';

void main() {
  group('FirebaseAuthStub', () {
    test('signUp + signIn keeps user session', () async {
      final auth = FirebaseAuthStub();

      final created = await auth.signUp(
        email: 'user@test.dev',
        password: 'secret1',
        displayName: 'User',
      );

      expect(auth.currentUser?.id, created.id);

      await auth.signOut();
      expect(auth.currentUser, isNull);

      final signedIn = await auth.signIn(
        email: 'user@test.dev',
        password: 'secret1',
      );

      expect(signedIn.email, 'user@test.dev');
      expect(auth.currentUser?.id, signedIn.id);
    });

    test('throws on duplicate email', () async {
      final auth = FirebaseAuthStub();

      await auth.signUp(
        email: 'dup@test.dev',
        password: 'secret1',
        displayName: 'First',
      );

      expect(
        () => auth.signUp(
          email: 'dup@test.dev',
          password: 'secret2',
          displayName: 'Second',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
