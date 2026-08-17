class Room {
  final String roomId;
  final String hostId;
  final String title;
  final String? examType;
  final String? subject;
  final String collectionName;
  final String questionSelection;
  final List<dynamic> questions;
  final int maxParticipants;
  final bool isPrivate;
  final String status;
  final List<RoomParticipant> participants;
  final double marks; // New property
  final double negativeMarks; // New property

  Room(
      {required this.roomId,
      required this.hostId,
      required this.title,
      this.examType,
      this.subject,
      required this.collectionName,
      required this.questionSelection,
      required this.questions,
      required this.maxParticipants,
      required this.isPrivate,
      required this.status,
      required this.participants,
      required this.marks,
      required this.negativeMarks});

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['roomId'] ?? '',
      hostId: json['hostId'] ?? '',
      title: json['title'] ?? '',
      examType: json['examType'],
      subject: json['subject'],
      collectionName: json['collectionName'] ?? 'pcsquestions',
      questionSelection: json['questionSelection'] ?? 'random',
      questions: json['questions'] ?? [],
      maxParticipants: json['maxParticipants'] ?? 4,
      isPrivate: json['isPrivate'] ?? false,
      status: json['status'] ?? 'active',
      participants: (json['participants'] as List? ?? [])
          .map((p) => RoomParticipant.fromJson(p))
          .toList(),
      marks: (json['marks'] as num? ?? 1.0).toDouble(), // Defaults to 1 mark
      negativeMarks: (json['negativeMarks'] as num? ?? 0.0)
          .toDouble(), // Defaults to 0 marks
    );
  }
}

class RoomParticipant {
  final String userId;
  final String userID;
  final String name;
  final double score;
  final int timeTakenSeconds;
  final String? completedAt;
  final String status;

  RoomParticipant({
    required this.userId,
    required this.userID,
    required this.name,
    required this.score,
    required this.timeTakenSeconds,
    this.completedAt,
    required this.status,
  });

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    return RoomParticipant(
      userId: json['userId'] ?? '',
      userID: json['userID'] ?? 'anonymous',
      name: json['name'] ?? 'Participant',
      score: (json['score'] as num? ?? 0).toDouble(),
      timeTakenSeconds: json['timeTakenSeconds'] ?? 0,
      completedAt: json['completedAt'],
      status: json['status'] ?? 'joined',
    );
  }
}

class RoomQuestion {
  final dynamic id;
  final String exam;
  final int year;
  final String subject;
  final String? topic;
  final String englishQuestion;
  final Map<String, dynamic> englishOptions;
  final String englishExplanation;
  final String hindiQuestion;
  final Map<String, dynamic> hindiOptions;
  final String hindiExplanation;
  final int correctAnswer;
  final double marks;
  final double negativeMarks;

  RoomQuestion({
    required this.id,
    required this.exam,
    required this.year,
    required this.subject,
    this.topic,
    required this.englishQuestion,
    required this.englishOptions,
    required this.englishExplanation,
    required this.hindiQuestion,
    required this.hindiOptions,
    required this.hindiExplanation,
    required this.correctAnswer,
    required this.marks,
    required this.negativeMarks,
  });

  factory RoomQuestion.fromJson(Map<String, dynamic> json) {
    final eng = json['english'] ?? {};
    final hin = json['hindi'] ?? {};
    return RoomQuestion(
      id: json['_id'],
      exam: json['exam'] ?? '',
      year: json['year'] ?? 2026,
      subject: json['subject'] ?? '',
      topic: json['topic'],
      englishQuestion: eng['question'] ?? '',
      englishOptions: Map<String, dynamic>.from(eng['options'] ?? {}),
      englishExplanation: eng['english_explanation'] ?? '',
      hindiQuestion: hin['question'] ?? '',
      hindiOptions: Map<String, dynamic>.from(hin['options'] ?? {}),
      hindiExplanation: hin['hindi_explanation'] ?? '',
      correctAnswer: json['correct_answer'] ?? 1,
      marks: (json['marks'] as num? ?? 2.0).toDouble(),
      negativeMarks: (json['negativeMarks'] as num? ?? 0.66).toDouble(),
    );
  }
}

class QuizAttempt {
  final dynamic questionId;
  final int selectedOption;
  final bool isCorrect;
  final bool isSkipped;
  final int timeTakenSeconds;
  final Map<String, dynamic> questionMeta;

  QuizAttempt({
    required this.questionId,
    required this.selectedOption,
    required this.isCorrect,
    required this.isSkipped,
    required this.timeTakenSeconds,
    required this.questionMeta,
  });

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'selectedOption': selectedOption,
      'isCorrect': isCorrect,
      'isSkipped': isSkipped,
      'timeTakenSeconds': timeTakenSeconds,
      'questionMeta': questionMeta,
    };
  }
}
