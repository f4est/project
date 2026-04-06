import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/src/app/app_dependencies.dart';
import 'package:project/src/app/home_workout_ai_app.dart';

void main() {
  testWidgets('user signs up with profile data and sees plan + ai summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      const HomeWorkoutAiApp(dependenciesBuilder: AppDependencies.createStub),
    );

    await tester.enterText(find.byKey(const Key('emailField')), 'fit@test.dev');
    await tester.enterText(find.byKey(const Key('passwordField')), 'secret1');
    await tester.enterText(find.byKey(const Key('nameField')), 'Fit User');
    await tester.enterText(find.byKey(const Key('ageField')), '29');
    await tester.enterText(find.byKey(const Key('heightField')), '178');
    await tester.enterText(find.byKey(const Key('weightField')), '74');
    await tester.enterText(
      find.byKey(const Key('occupationField')),
      'Разработчик',
    );
    await tester.ensureVisible(find.byKey(const Key('goalDropdown')));
    await tester.tap(find.byKey(const Key('goalDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Рост мышц').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('signUpButton')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('FitPilot'), findsWidgets);
    expect(find.byKey(const Key('planList')), findsOneWidget);
    expect(find.text('Рекомендации на сегодня'), findsOneWidget);
  });
}
