class UserProfile {
  final String userId;
  final String? userID;
  final String? examType;
  final String? displayName;
  final String? email;
  final bool profileComplete;

  const UserProfile({
    required this.userId,
    this.userID,
    this.examType,
    this.displayName,
    this.email,
    this.profileComplete = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'] as Map<String, dynamic>? ?? json;
    final examType = profileJson['examType']?.toString();
    return UserProfile(
      userId: profileJson['userId']?.toString() ?? '',
      userID: profileJson['userID']?.toString(),
      examType: examType,
      displayName: profileJson['displayName']?.toString(),
      email: profileJson['email']?.toString(),
      profileComplete: examType != null && examType.isNotEmpty,
    );
  }
}

class AnalyticsSummary {
  final int totalAttempted;
  final int totalCorrect;
  final int totalIncorrect;
  final int totalSkipped;
  final double overallAccuracy;
  final int totalStudyTimeSeconds;
  final double avgResponseTimeSeconds;
  final int currentStreak;
  final int longestStreak;
  final List<Map<String, dynamic>> subjectAccuracy;
  final List<String> strongSubjects;
  final List<String> weakSubjects;
  final List<Map<String, dynamic>> performanceTrend;

  const AnalyticsSummary({
    this.totalAttempted = 0,
    this.totalCorrect = 0,
    this.totalIncorrect = 0,
    this.totalSkipped = 0,
    this.overallAccuracy = 0,
    this.totalStudyTimeSeconds = 0,
    this.avgResponseTimeSeconds = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.subjectAccuracy = const [],
    this.strongSubjects = const [],
    this.weakSubjects = const [],
    this.performanceTrend = const [],
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    final analytics = json['analytics'] as Map<String, dynamic>? ?? json;
    return AnalyticsSummary(
      totalAttempted: (analytics['totalAttempted'] as num?)?.toInt() ?? 0,
      totalCorrect: (analytics['totalCorrect'] as num?)?.toInt() ?? 0,
      totalIncorrect: (analytics['totalIncorrect'] as num?)?.toInt() ?? 0,
      totalSkipped: (analytics['totalSkipped'] as num?)?.toInt() ?? 0,
      overallAccuracy: (analytics['overallAccuracy'] as num?)?.toDouble() ?? 0,
      totalStudyTimeSeconds:
          (analytics['totalStudyTimeSeconds'] as num?)?.toInt() ?? 0,
      avgResponseTimeSeconds:
          (analytics['avgResponseTimeSeconds'] as num?)?.toDouble() ?? 0,
      currentStreak: (analytics['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (analytics['longestStreak'] as num?)?.toInt() ?? 0,
      subjectAccuracy:
          List<Map<String, dynamic>>.from(analytics['subjectAccuracy'] ?? []),
      strongSubjects: List<String>.from(analytics['strongSubjects'] ?? []),
      weakSubjects: List<String>.from(analytics['weakSubjects'] ?? []),
      performanceTrend:
          List<Map<String, dynamic>>.from(analytics['performanceTrend'] ?? []),
    );
  }
}
