import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'quiz.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Science Signal B',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const AccountGate(),
    ),
  );
}

class AccountGate extends StatefulWidget {
  const AccountGate({super.key});
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  final email = TextEditingController();
  final password = TextEditingController();
  late final auth = FirebaseAuth.instance.authStateChanges();
  String error = '';
  bool busy = false;

  Future<void> signIn() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on FirebaseAuthException catch (failure) {
      if (mounted) setState(() => error = 'Sign-in failed: ${failure.code}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: auth,
    builder: (context, snapshot) {
      final user = snapshot.data;
      if (user != null) return ScienceQuizScreen(key: ValueKey(user.uid));
      return Scaffold(
        appBar: AppBar(title: const Text('Science Signal B')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Sign in to save your science round'),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            FilledButton(
              onPressed: busy ? null : signIn,
              child: const Text('Sign in'),
            ),
            Text(error),
          ],
        ),
      );
    },
  );
}
