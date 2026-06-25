class QuestionOption {
  final String key;
  final String value;

  const QuestionOption({required this.key, required this.value});
}

class Question {
  final dynamic id;
  final String exam;
  final int year;
  final String? paper;
  final String subject;
  final String? topic;
  final String? imageUrl;
  final String questionText;
  final Map<String, String> options;
  final int correctAnswer;
  final double marks;
  final double negativeMarks;
  final String? explanation;
  final String? batchId;

  const Question({
    required this.id,
    required this.exam,
    required this.year,
    this.paper,
    required this.subject,
    this.topic,
    this.imageUrl,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.marks = 2,
    this.negativeMarks = 0.66,
    this.explanation,
    this.batchId,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final englishData = json['english'] as Map<String, dynamic>? ?? {};
    final rawOptions = englishData['options'] as Map<String, dynamic>? ?? {};
    final parsedOptions = <String, String>{};
    rawOptions.forEach((k, v) {
      parsedOptions[k] = v?.toString() ?? '';
    });

    return Question(
      id: json['_id'],
      exam: json['exam']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      paper: json['paper']?.toString(),
      subject: json['subject']?.toString() ?? '',
      topic: json['topic']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      questionText: englishData['question']?.toString() ?? '',
      options: parsedOptions,
      correctAnswer: (json['correct_answer'] as num?)?.toInt() ?? 1,
      marks: (json['marks'] as num?)?.toDouble() ?? 2.0,
      negativeMarks: (json['negativeMarks'] as num?)?.toDouble() ?? 0.66,
      explanation: json['explanation']?.toString(),
      batchId: json['batchId']?.toString(),
    );
  }

  List<QuestionOption> get optionList {
    final sorted = options.entries.toList()
      ..sort(
        (a, b) =>
            int.tryParse(a.key)?.compareTo(int.tryParse(b.key) ?? 0) ??
            a.key.compareTo(b.key),
      );
    return sorted
        .map((e) => QuestionOption(key: e.key, value: e.value))
        .toList();
  }

  Map<String, dynamic> toMeta() => {
        'exam': exam,
        'subject': subject,
        'topic': topic,
        'paper': paper,
        'year': year,
        'marks': marks,
        'negativeMarks': negativeMarks,
      };
}
