import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'attempt_repository.dart';

import 'package:http/http.dart' as http;

class ScienceQuestion {
  const ScienceQuestion({required this.text, required this.correctAnswer});

  final String text;
  final String correctAnswer;

  factory ScienceQuestion.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['question'] is! String ||
        value['correct_answer'] is! String ||
        value['incorrect_answers'] is! List) {
      throw const FormatException('Invalid question data.');
    }

    if (value['category'] is! String ||
        Uri.decodeComponent(value['category'] as String) !=
            'Science & Nature' ||
        value['difficulty'] != 'medium' ||
        value['type'] != 'boolean') {
      throw const FormatException('Unexpected science question metadata.');
    }
    final text = Uri.decodeComponent(value['question'] as String);
    final correctAnswer = Uri.decodeComponent(
      value['correct_answer'] as String,
    );
    final incorrectAnswers = value['incorrect_answers'] as List;
    if (text.trim().isEmpty ||
        (correctAnswer != 'True' && correctAnswer != 'False') ||
        incorrectAnswers.length != 1 ||
        incorrectAnswers.first is! String) {
      throw const FormatException('Invalid true-or-false question.');
    }
    final incorrectAnswer = Uri.decodeComponent(
      incorrectAnswers.first as String,
    );
    if ((incorrectAnswer != 'True' && incorrectAnswer != 'False') ||
        incorrectAnswer == correctAnswer) {
      throw const FormatException('Invalid true-or-false answers.');
    }
    return ScienceQuestion(text: text, correctAnswer: correctAnswer);
  }
}

class ScienceQuizScreen extends StatefulWidget {
  const ScienceQuizScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<ScienceQuizScreen> createState() => _ScienceQuizScreenState();
}

class _ScienceQuizScreenState extends State<ScienceQuizScreen> {
  static final _questionUri = Uri.https('opentdb.com', '/api.php', {
    'amount': '5',
    'category': '17',
    'difficulty': 'medium',
    'type': 'boolean',
    'encode': 'url3986',
  });

  List<ScienceQuestion> _questions = [];
  final _answers = <String>[];

  final repository = AttemptRepository(FirebaseFirestore.instance);
  late final uid = FirebaseAuth.instance.currentUser!.uid;
  String? roundId;
  bool acknowledged = false;
  bool unresolved = false;
  String cloudStatus = 'Ready to submit';
  bool _sending = false;
  bool verified = false;
  bool _loading = true;
  bool _requestPending = false;
  Future<void>? _commitPending;
  bool _verifyPending = false;
  final lookup = TextEditingController();
  String lookupStatus = '';
  String? fault;

  int get _score => _answers
      .asMap()
      .entries
      .where((entry) => entry.value == _questions[entry.key].correctAnswer)
      .length;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  DateTime? lastRequest;
  Future<void> _loadQuestions() async {
    if (_requestPending) return;
    _requestPending = true;
    final previous = lastRequest;
    if (previous != null) {
      final remaining =
          const Duration(seconds: 5) - DateTime.now().difference(previous);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (!mounted) return;
    }
    lastRequest = DateTime.now();
    setState(() {
      _loading = true;
      _error = null;
      _questions = [];
      roundId = FirebaseFirestore.instance
          .collection('users/$uid/attempts')
          .doc()
          .id;
      acknowledged = false;
      unresolved = false;
      cloudStatus = 'Ready to submit';
      _answers.clear();
      _questionIndex = 0;
      verified = false;
    });

    try {
      final response =
          await (widget.client?.get(_questionUri) ?? http.get(_questionUri))
              .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw FormatException('Server returned HTTP ${response.statusCode}.');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['response_code'] != 0) {
        throw const FormatException('The trivia API did not return questions.');
      }
      final results = data['results'];
      if (results is! List || results.length != 5) {
        throw const FormatException('Expected five trivia questions.');
      }
      final questions = results.map(ScienceQuestion.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } on http.ClientException catch (error) {
      _showError('The request failed: ${error.message}');
    } on FormatException catch (error) {
      _showError('Could not load questions: ${error.message}');
    } finally {
      _requestPending = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  Future<void> save({bool readOnly = false}) async {
    if (_sending || _verifyPending || roundId == null) return;
    final owner = uid;
    final id = roundId!;
    setState(() {
      _sending = true;
      unresolved = true;
      cloudStatus = readOnly ? 'Verifying…' : 'Submitting…';
    });
    try {
      if (!readOnly) {
        final pending = repository.commit(owner, id, _score);
        _commitPending = pending;
        pending.then(
          (_) {
            _commitPending = null;
          },
          onError: (Object e) {
            _commitPending = null;
          },
        );
        await pending.timeout(const Duration(seconds: 10));
        acknowledged = true;
      }
      if (acknowledged && fault != null) {
        repository.injectedVerificationError = fault;
        fault = null;
      }
      _verifyPending = true;
      final pending = repository.verify(owner, id, _score);
      pending.then(
        (_) {
          _verifyPending = false;
        },
        onError: (Object e) {
          _verifyPending = false;
        },
      );
      await pending.timeout(const Duration(seconds: 10));
      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != owner ||
          roundId != id) {
        return;
      }
      setState(() {
        cloudStatus = 'Cloud verified';
        unresolved = false;
        verified = true;
      });
    } on AttemptMissing {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != owner) return;
      setState(() {
        unresolved = _commitPending != null;
        cloudStatus = unresolved
            ? 'No record yet; original operation remains pending. Verify again.'
            : 'Server confirmed no record. Retry save with this same ID.';
      });
    } on AttemptCollision {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != owner) return;
      setState(() {
        cloudStatus =
            'ID collision: existing score differs. Original record preserved.';
        unresolved = false;
        verified = true;
      });
    } catch (error) {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != owner) return;
      setState(
        () => cloudStatus = acknowledged
            ? 'Write acknowledged; verification unavailable. $error'
            : 'Save outcome unknown. Reconcile this ID before retrying. $error',
      );
    } finally {
      if (mounted && FirebaseAuth.instance.currentUser?.uid == owner) {
        setState(() => _sending = false);
      }
    }
  }

  Widget _round() {
    final index = _questionIndex;
    final question = _questions[index];
    final answered = _answers.length > index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Question ${index + 1} of 5'),
        const SizedBox(height: 16),
        Text(question.text, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        for (final choice in ['True', 'False'])
          OutlinedButton(
            style: answered
                ? OutlinedButton.styleFrom(
                    disabledForegroundColor: choice == question.correctAnswer
                        ? Colors.green.shade800
                        : _answers[index] == choice
                        ? Theme.of(context).colorScheme.error
                        : null,
                  )
                : null,
            onPressed: answered
                ? null
                : () {
                    if (_answers.length == index) {
                      setState(() => _answers.add(choice));
                    }
                  },
            child: Text(choice),
          ),
        if (answered) ...[
          Text(
            _answers[index] == question.correctAnswer
                ? 'Correct!'
                : 'Incorrect. The correct answer is ${question.correctAnswer}.',
          ),
          FilledButton(
            onPressed: () => setState(() => _questionIndex++),
            child: Text(index == 4 ? 'See results' : 'Next question'),
          ),
        ],
      ],
    );
  }

  int _questionIndex = 0;

  Widget _results() {
    final payload = jsonEncode({
      ...repository.fields(_score),
      'submittedAt': 'Verified resolved server timestamp',
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Score: $_score / 5',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Round ID: $roundId'),
        Container(
          padding: const EdgeInsets.all(16),
          color: verified ? Colors.teal.shade50 : Colors.amber.shade100,
          child: Text(cloudStatus, key: const Key('cloud-status')),
        ),
        if (AttemptRepository.testHooks && !acknowledged && !verified)
          DropdownButton<String>(
            value: fault,
            hint: const Text('Development-only fault injection'),
            items: ['permission-denied', 'unavailable', 'resource-exhausted']
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text('INJECT: $code'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => fault = value),
          ),
        if (unresolved)
          OutlinedButton(
            onPressed: _sending ? null : () => save(readOnly: true),
            child: const Text('Retry server verification'),
          ),
        for (final (index, question) in _questions.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${index + 1}. ${question.text}'),
            subtitle: Text(
              'Your answer: ${_answers[index]} - Correct answer: ${question.correctAnswer}',
            ),
          ),
        FilledButton(
          onPressed: _sending || verified || unresolved ? null : () => save(),
          child: Text(_sending ? 'Submitting...' : 'Save to cloud'),
        ),
        if (verified) ...[Text(cloudStatus), SelectableText(payload)],
        OutlinedButton(
          onPressed: _sending || unresolved
              ? null
              : () {
                  _questionIndex = 0;
                  _loadQuestions();
                },
          child: const Text('Play again'),
        ),
      ],
    );
  }

  Future<void> retrieve() async {
    final id = lookup.text.trim();
    if (id.isEmpty || id.contains('/')) return;
    setState(() => lookupStatus = 'Reading server...');
    try {
      final record = await repository
          .verify(uid, id, null)
          .timeout(const Duration(seconds: 10));
      if (mounted && FirebaseAuth.instance.currentUser?.uid == uid)
        setState(
          () => lookupStatus =
              'Cloud verified: ${record.data()!['correctCount']} / 5; submittedAt ${record.data()!['submittedAt'].toDate().toUtc()}; cache=false; pending=false',
        );
    } catch (error) {
      if (mounted)
        setState(() => lookupStatus = 'Server retrieval failed: $error');
    }
  }

  @override
  void dispose() {
    lookup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Science Signal B'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: unresolved || _sending
              ? null
              : () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading questions',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ExpansionTile(
                  title: const Text('Retrieve a saved round'),
                  children: [
                    TextField(
                      controller: lookup,
                      decoration: const InputDecoration(
                        labelText: 'Saved round ID',
                      ),
                    ),
                    TextButton(
                      onPressed: retrieve,
                      child: const Text('Read from server'),
                    ),
                    Text(lookupStatus),
                  ],
                ),
                if (_error case final error?) ...[
                  Text(error),
                  FilledButton(
                    onPressed: _loadQuestions,
                    child: const Text('Retry'),
                  ),
                ] else if (_questionIndex == _questions.length)
                  _results()
                else
                  _round(),
              ],
            ),
    ),
  );
}
