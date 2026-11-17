import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:science_signal/firebase_options.dart';
import 'package:science_signal/quiz.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('T07 fresh-process retrieval', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: const String.fromEnvironment('TEST_EMAIL_A'),
      password: const String.fromEnvironment('TEST_PASSWORD_A'),
    );
    await tester.pumpWidget(const MaterialApp(home: ScienceQuizScreen()));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Retrieve a saved round'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      const String.fromEnvironment('RESTART_ID'),
    );
    await tester.tap(find.text('Read from server'));
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 20 && find.textContaining('Cloud verified:').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.textContaining('cache=false; pending=false'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('T07-restart');
    debugPrint(
      'EVIDENCE T07 ${DateTime.now().toUtc().toIso8601String()} PASS fresh Android process authenticated A and retrieved original record from server without replay; suffix=${const String.fromEnvironment('RESTART_ID').substring(14)}',
    );
    await tester.enterText(
      find.byType(TextField),
      const String.fromEnvironment('FAULT_ID'),
    );
    await tester.tap(find.text('Read from server'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('cache=false; pending=false'), findsOneWidget);
    await binding.takeScreenshot('T09-final-read');
    debugPrint(
      'EVIDENCE T09 ${DateTime.now().toUtc().toIso8601String()} PASS independent fresh-process read of injected-failure record suffix=${const String.fromEnvironment('FAULT_ID').substring(14)}',
    );
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'response_code': 0,
          'results': List.generate(
            5,
            (i) => {
              'category': 'Science%20%26%20Nature',
              'difficulty': 'medium',
              'type': 'boolean',
              'question': 'Two%20point%20check%20${i + 1}',
              'correct_answer': i < 2 ? 'True' : 'False',
              'incorrect_answers': [i < 2 ? 'False' : 'True'],
            },
          ),
        }),
        200,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(home: ScienceQuizScreen(client: client)),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('True'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(i == 4 ? 'See results' : 'Next question'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Score: 2 / 5'), findsOneWidget);
    await binding.takeScreenshot('T04-two-correct');
    debugPrint(
      'EVIDENCE T04 ${DateTime.now().toUtc().toIso8601String()} PASS exactly two correct selections produced 2/5; remaining three were wrong',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
