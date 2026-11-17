import 'package:flutter_test/flutter_test.dart';
import 'package:science_signal/quiz.dart';

Map<String, dynamic> question() => {
  'category': 'Science%20%26%20Nature',
  'difficulty': 'medium',
  'type': 'boolean',
  'question': 'Water%20%26%20ice%3F',
  'correct_answer': 'True',
  'incorrect_answers': ['False'],
};
void main() {
  test('decodes URI text and checks fixed metadata', () {
    expect(ScienceQuestion.fromJson(question()).text, 'Water & ice?');
  });
  test('rejects corrupt encoding and duplicate answers', () {
    expect(
      () => ScienceQuestion.fromJson({...question(), 'question': 'bad%ZZ'}),
      throwsFormatException,
    );
    expect(
      () => ScienceQuestion.fromJson({
        ...question(),
        'incorrect_answers': ['True'],
      }),
      throwsFormatException,
    );
    expect(
      () => ScienceQuestion.fromJson({...question(), 'category': 'History'}),
      throwsFormatException,
    );
  });
}
