enum AppLanguage { english, hindi }

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

  final String englishQuestionText;
  final Map<String, String> englishOptions;
  final String? englishExplanation;

  final String hindiQuestionText;
  final Map<String, String> hindiOptions;
  final String? hindiExplanation;

  final int correctAnswer;
  final double marks;
  final double negativeMarks;
  final String? batchId;

  const Question({
    required this.id,
    required this.exam,
    required this.year,
    this.paper,
    required this.subject,
    this.topic,
    this.imageUrl,
    required this.englishQuestionText,
    required this.englishOptions,
    this.englishExplanation,
    required this.hindiQuestionText,
    required this.hindiOptions,
    this.hindiExplanation,
    required this.correctAnswer,
    this.marks = 2,
    this.negativeMarks = 0.66,
    this.batchId,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final englishData = json['english'] as Map<String, dynamic>? ?? {};
    final hindiData = json['hindi'] as Map<String, dynamic>? ?? {};

    Map<String, String> parseOptions(Map<String, dynamic>? raw) {
      final parsed = <String, String>{};
      raw?.forEach((k, v) {
        parsed[k] = v?.toString() ?? '';
      });
      return parsed;
    }

    return Question(
      id: json['_id'],
      exam: json['exam']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      paper: json['paper']?.toString(),
      subject: json['subject']?.toString() ?? '',
      topic: json['topic']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      englishQuestionText: englishData['question']?.toString() ?? '',
      englishOptions:
          parseOptions(englishData['options'] as Map<String, dynamic>?),
      englishExplanation: englishData['english_explanation']?.toString(),
      hindiQuestionText: hindiData['question']?.toString() ?? '',
      hindiOptions: parseOptions(hindiData['options'] as Map<String, dynamic>?),
      hindiExplanation: hindiData['hindi_explanation']?.toString(),
      correctAnswer: (json['correct_answer'] as num?)?.toInt() ?? 1,
      marks: (json['marks'] as num?)?.toDouble() ?? 2.0,
      negativeMarks: (json['negativeMarks'] as num?)?.toDouble() ?? 0.66,
      batchId: json['batchId']?.toString(),
    );
  }

  String questionText(AppLanguage lang) {
    if (lang == AppLanguage.hindi && hindiQuestionText.isNotEmpty) {
      return hindiQuestionText;
    }
    return englishQuestionText;
  }

  Map<String, String> optionsFor(AppLanguage lang) {
    if (lang == AppLanguage.hindi && hindiOptions.isNotEmpty) {
      return hindiOptions;
    }
    return englishOptions;
  }

  String? explanation(AppLanguage lang) {
    if (lang == AppLanguage.hindi && (hindiExplanation?.isNotEmpty ?? false)) {
      return hindiExplanation;
    }
    return englishExplanation;
  }

  List<QuestionOption> optionList(AppLanguage lang) {
    final sorted = optionsFor(lang).entries.toList()
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
