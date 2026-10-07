import 'package:flutter_test/flutter_test.dart';
import 'package:vivduck/core/models.dart';

void main() {
  test('a custom question is sent as custom_question, not question_id', () {
    final req = CreateSessionRequest(
      studentName: 'Alice',
      question: Question.custom('  Explain photosynthesis.  ', subject: 'Bio'),
      answerText: 'Plants use light.',
    );
    final j = req.toJson();
    expect(j.containsKey('question_id'), isFalse);
    expect(j['custom_question'], {
      'prompt': 'Explain photosynthesis.',
      'subject': 'Bio',
    });
  });

  test('a picked question is sent by id', () {
    const q = Question(
      id: 'q_1',
      title: 'T',
      subject: '',
      prompt: 'P',
      marks: 10,
      points: 4,
      origin: 'teacher',
      author: 'Ms. Rivera',
    );
    final j = CreateSessionRequest(
      studentName: 'A',
      question: q,
      answerText: 'x',
    ).toJson();
    expect(j['question_id'], 'q_1');
    expect(Question.fromJson(q.toJson()).author, 'Ms. Rivera');
  });

  test('a drafted rubric round-trips through the editor shape', () {
    final d = QuestionDraft.fromJson({
      'title': 'Photosynthesis',
      'subject': 'Biology',
      'prompt': 'Explain photosynthesis.',
      'marks': 10,
      'points': [
        {'statement': 'Light becomes chemical energy.', 'weight': 5},
      ],
      'trap': {'false_claim': 'Mass comes from soil.', 'truth': 'From CO2.'},
      'what_if': 'What if it is dark?',
    });
    expect(d.points.single.weight, 3, reason: 'weights are clamped to 1-3');
    expect(d.toJson()['trap'], {
      'false_claim': 'Mass comes from soil.',
      'truth': 'From CO2.',
    });
  });
}
