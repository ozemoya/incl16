import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:science_signal/firebase_options.dart';
import 'package:science_signal/quiz.dart';

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
  }, timeout: const Timeout(Duration(minutes: 2)));
}
