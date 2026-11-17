import 'package:cloud_firestore/cloud_firestore.dart';

class AttemptCollision implements Exception {}

class AttemptMissing implements Exception {}

class AttemptRepository {
  AttemptRepository(this.firestore);
  final FirebaseFirestore firestore;
  static const testHooks = bool.fromEnvironment('ENABLE_TEST_HOOKS');
  String? injectedVerificationError;

  DocumentReference<Map<String, dynamic>> reference(String uid, String id) =>
      firestore.doc('users/$uid/attempts/$id');

  Map<String, dynamic> fields(int score) => {
    'schemaVersion': 1,
    'variant': 'B',
    'categoryId': 17,
    'questionCount': 5,
    'correctCount': score,
  };

  bool matches(Map<String, dynamic> data, int score) {
    final expected = fields(score);
    return expected.entries.every((entry) => data[entry.key] == entry.value);
  }

  Future<void> commit(String uid, String id, int score) async {
    final ref = reference(uid, id);
    final payload = {
      ...fields(score),
      'submittedAt': FieldValue.serverTimestamp(),
    };
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        if (!matches(snapshot.data()!, score)) throw AttemptCollision();
        return;
      }
      transaction.set(ref, payload);
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> verify(
    String uid,
    String id,
    int? score,
  ) async {
    final fault = injectedVerificationError;
    injectedVerificationError = null;
    if (testHooks && fault != null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: fault,
        message: 'Development-only verification injection',
      );
    }
    final snapshot = await reference(
      uid,
      id,
    ).get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) throw AttemptMissing();
    if (data.length != 6 ||
        (score != null && !matches(data, score)) ||
        data['schemaVersion'] != 1 ||
        data['schemaVersion'] is! int ||
        data['variant'] != 'B' ||
        data['categoryId'] != 17 ||
        data['categoryId'] is! int ||
        data['questionCount'] != 5 ||
        data['questionCount'] is! int ||
        data['correctCount'] is! int ||
        (data['correctCount'] as int) < 0 ||
        (data['correctCount'] as int) > 5 ||
        data['submittedAt'] is! Timestamp ||
        snapshot.metadata.hasPendingWrites ||
        snapshot.metadata.isFromCache) {
      throw StateError('Server record does not match this attempt');
    }
    return snapshot;
  }
}
