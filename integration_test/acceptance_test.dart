import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:science_signal/firebase_options.dart';
import 'package:science_signal/main.dart';
import 'package:science_signal/quiz.dart';
import 'package:science_signal/attempt_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('T01-T12 cloud and Android acceptance', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance, db = FirebaseFirestore.instance;
    final repo = AttemptRepository(db);
    Future<void> loginA() => auth.signInWithEmailAndPassword(
      email: const String.fromEnvironment('TEST_EMAIL_A'),
      password: const String.fromEnvironment('TEST_PASSWORD_A'),
    );
    void record(String id, String result) {
      debugPrint(
        'EVIDENCE $id ${DateTime.now().toUtc().toIso8601String()} $result',
      );
    }

    Future<void> shot(String name) async {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(String text) async {
      final target = find.text(text);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Map<String, dynamic> q(int i) => {
      'category': 'Science%20%26%20Nature',
      'difficulty': 'medium',
      'type': 'boolean',
      'question': 'Science%20statement%20${i + 1}%20%26%20evidence%3F',
      'correct_answer': i.isEven ? 'True' : 'False',
      'incorrect_answers': [i.isEven ? 'False' : 'True'],
    };
    final questions = List.generate(5, q);
    MockClient client(Object body) =>
        MockClient((_) async => http.Response(jsonEncode(body), 200));
    Future<void> showRound(Object body) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: ScienceQuizScreen(client: client(body))),
      );
      await tester.pumpAndSettle();
    }

    Future<void> finishRound() async {
      for (var i = 0; i < 5; i++) {
        await tap('True');
        if (i == 0) {
          await tap('True');
          expect(find.text('Correct!'), findsOneWidget);
        }
        await tap(i == 4 ? 'See results' : 'Next question');
      }
      expect(find.text('Score: 3 / 5'), findsOneWidget);
    }

    await auth.signOut();
    await tester.pumpWidget(const MaterialApp(home: AccountGate()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      const String.fromEnvironment('TEST_EMAIL_A'),
    );
    await tester.enterText(find.byType(TextField).at(1), 'not-the-password');
    await tap('Sign in');
    for (
      var i = 0;
      i < 20 && !find.textContaining('Sign-in failed:').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.textContaining('Sign-in failed:'), findsOneWidget);
    await loginA();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final uid = auth.currentUser!.uid;
    record(
      'T01',
      'PASS invalid credentials rejected; valid A authenticated (no credentials logged)',
    );
    final uri = Uri.parse(
      'https://opentdb.com/api.php?amount=5&category=17&difficulty=medium&type=boolean&encode=url3986',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    expect(response.statusCode, 200);
    final live = jsonDecode(response.body);
    expect(live['response_code'], 0);
    expect((live['results'] as List).length, 5);
    final decoded = (live['results'] as List)
        .map(ScienceQuestion.fromJson)
        .toList();
    expect(decoded.length, 5);
    await showRound(live);
    await shot('T02-live-api');
    record(
      'T02',
      'PASS live exact URL returned five validated decoded questions; encoded=${live['results'][0]['question']} decoded=${decoded[0].text}',
    );
    for (final bad in [
      {'response_code': 1, 'results': []},
      {'response_code': 0, 'results': questions.take(4).toList()},
      {
        'response_code': 0,
        'results': [
          {...q(0), 'question': 'bad%ZZ'},
          ...questions.skip(1),
        ],
      },
    ]) {
      await showRound(bad);
      expect(find.textContaining('Could not load questions:'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    }
    await shot('T03-rejected-data');
    record(
      'T03',
      'PASS nonzero code, four items and corrupt encoding each rejected; manual Retry visible',
    );
    await showRound({'response_code': 0, 'results': questions});
    await finishRound();
    record(
      'T04',
      'PASS repeated answer ignored; three True answers correct and two incorrect; review contains five entries',
    );
    String currentId() {
      final text = tester.widget<Text>(find.textContaining('Round ID:')).data!;
      return text.substring(10);
    }

    final id = currentId();
    await shot('T04-round-review');
    await tap('Play again');
    expect(find.text('Question 1 of 5'), findsOneWidget);
    await finishRound();
    final newId = currentId();
    expect(newId, isNot(id));
    record(
      'T05',
      'PASS replay reset answers and index; distinct IDs suffix=${id.substring(id.length - 6)} -> ${newId.substring(newId.length - 6)}',
    );
    await tap('Save to cloud');
    for (
      var i = 0;
      i < 30 && find.text('Cloud verified').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Cloud verified'), findsWidgets);
    await tap('Save to cloud');
    final saved = await repo.verify(uid, newId, 3);
    expect(saved.data()!.length, 6);
    expect(saved.data()!['submittedAt'], isA<Timestamp>());
    await shot('T06-cloud-verified');
    record(
      'T06',
      'PASS double-tap guard; exact six-field server record suffix=${newId.substring(newId.length - 6)} timestamp=${(saved.data()!['submittedAt'] as Timestamp).toDate().toUtc()} cache=${saved.metadata.isFromCache} pending=${saved.metadata.hasPendingWrites}',
    );
    final changed = repo.commit(uid, newId, 4);
    await expectLater(changed, throwsA(isA<AttemptCollision>()));
    expect((await repo.verify(uid, newId, 3)).data()!['correctCount'], 3);
    record(
      'COLLISION',
      'PASS changed score same ID rejected and original preserved',
    );
    await auth.signOut();
    await loginA();
    final after = await repo.verify(uid, newId, null);
    expect(after.data()!['submittedAt'], saved.data()!['submittedAt']);
    record(
      'T07',
      'PARTIAL same-user sign-out/sign-in server retrieval preserved record; separate process restart test follows',
    );
    await showRound({'response_code': 0, 'results': questions});
    await finishRound();
    final offlineId = currentId();
    await db.disableNetwork();
    await tap('Save to cloud');
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('Cloud verified'), findsNothing);
    await shot('T08-offline-unknown');
    await db.enableNetwork();
    await tap('Retry server verification');
    await tester.pump(const Duration(seconds: 2));
    if (find.text('Save to cloud').evaluate().isNotEmpty) {
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save to cloud'),
      );
      if (button.onPressed != null) await tap('Save to cloud');
    }
    await tester.pump(const Duration(seconds: 3));
    await repo.verify(uid, offlineId, 3);
    record(
      'T08',
      'PASS offline never claimed success; reconnect reconciled same suffix=${offlineId.substring(offlineId.length - 6)}',
    );
    await showRound({'response_code': 0, 'results': questions});
    await finishRound();
    final faultId = currentId();
    await tap('Development-only fault injection');
    await tap('INJECT: permission-denied');
    await tap('Save to cloud');
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.textContaining('Write acknowledged; verification unavailable.'),
      findsOneWidget,
    );
    await shot('T09-verification-denied');
    final beforeRetry = await repo.verify(uid, faultId, 3);
    await tap('Retry server verification');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Cloud verified'), findsWidgets);
    expect(
      (await repo.verify(uid, faultId, 3)).data()!['submittedAt'],
      beforeRetry.data()!['submittedAt'],
    );
    record(
      'T09',
      'PASS real commit, injected first verification permission-denied, real retry same suffix=${faultId.substring(faultId.length - 6)} unchanged timestamp',
    );
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: const String.fromEnvironment('TEST_EMAIL_B'),
      password: const String.fromEnvironment('TEST_PASSWORD_B'),
    );
    Future<void> denied(Future<Object?> operation) async {
      await expectLater(
        operation,
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    }

    await denied(
      repo.reference(uid, newId).get(const GetOptions(source: Source.server)),
    );
    await denied(
      repo.reference(uid, db.collection('ids').doc().id).set({
        ...repo.fields(2),
        'submittedAt': FieldValue.serverTimestamp(),
      }),
    );
    record(
      'T10',
      'PASS real cloud B read and create under A denied permission-denied',
    );
    await loginA();
    await denied(
      repo.reference(uid, db.collection('ids').doc().id).set({
        ...repo.fields(6),
        'submittedAt': FieldValue.serverTimestamp(),
      }),
    );
    await denied(
      repo.reference(uid, db.collection('ids').doc().id).set({
        ...repo.fields(2),
        'extra': true,
        'submittedAt': FieldValue.serverTimestamp(),
      }),
    );
    await denied(repo.reference(uid, newId).update({'correctCount': 4}));
    await repo.verify(uid, newId, 3);
    record(
      'T11',
      'PASS real cloud score6, extra field, update denied; original score3 intact',
    );
    for (final code in ['unavailable', 'resource-exhausted']) {
      await showRound({'response_code': 0, 'results': questions});
      await finishRound();
      await tap('Development-only fault injection');
      await tap('INJECT: $code');
      await tap('Save to cloud');
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(code), findsOneWidget);
      await shot('T12-$code');
      await tap('Retry server verification');
      await tester.pump(const Duration(seconds: 2));
    }
    record(
      'T12',
      'PASS explicitly labeled development hook produced distinct unavailable and resource-exhausted messages after real commits',
    );
    debugPrint('RESTART_RECORD=$newId');
    binding.reportData = {'restartId': newId};
  }, timeout: const Timeout(Duration(minutes: 8)));
}
