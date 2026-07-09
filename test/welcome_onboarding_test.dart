import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:are_you_alive_flutter/screens/welcome_screen.dart';
import 'package:are_you_alive_flutter/widgets/animated_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('proceed button is disabled until a non-empty name is entered', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onComplete: () => completed = true)),
    );

    await tester.tap(find.text('proceed'));
    await tester.pump();

    expect(completed, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasCompletedOnboarding'), isNull);
  });

  testWidgets(
    'a name consisting only of whitespace is treated as empty (button stays disabled)',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onComplete: () => completed = true)),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.text('proceed'));
      await tester.pump();

      expect(
        completed,
        isFalse,
        reason:
            '_validateName trims before checking isNotEmpty, so whitespace-only '
            'input must not enable the proceed button.',
      );
    },
  );

  testWidgets(
    'entering a name and proceeding persists a trimmed userName and marks onboarding complete',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onComplete: () => completed = true)),
      );

      await tester.enterText(find.byType(TextField), '  Yash  ');
      await tester.pump();
      await tester.tap(find.text('proceed'));
      await tester.pump();

      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('userName'), 'Yash');
      expect(prefs.getBool('hasCompletedOnboarding'), isTrue);
    },
  );

  testWidgets(
    'the proceed AnimatedButton has a null onPressed callback while the name field is empty, '
    'and a non-null callback once text is entered',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onComplete: () {})),
      );

      AnimatedButton buttonWidget() =>
          tester.widget<AnimatedButton>(find.byType(AnimatedButton));

      expect(buttonWidget().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Yash');
      await tester.pump();

      expect(buttonWidget().onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(
        buttonWidget().onPressed,
        isNull,
        reason: 'Clearing the name back out must re-disable the button.',
      );
    },
  );

  testWidgets(
    'clearing the name field back to empty after it was valid disables proceed again',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(home: WelcomeScreen(onComplete: () => completed = true)),
      );

      await tester.enterText(find.byType(TextField), 'Yash');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('proceed'));
      await tester.pump();

      expect(completed, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('userName'), isFalse);
    },
  );
}
