import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.baseUrl}/health'))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getQuestions({
    String collection = 'pcsquestions',
    String? exam,
    int limit = 20,
    int skip = 0,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/questions').replace(
      queryParameters: {
        'collection': collection,
        if (exam != null) 'exam': exam,
        'limit': limit.toString(),
        'skip': skip.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['questions'] ?? []);
    }
    throw Exception('Failed to fetch questions: ${res.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getRandomQuestions({
    String collection = 'pcsquestions',
    String? exam,
    int count = 20,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/questions/random').replace(
      queryParameters: {
        'collection': collection,
        if (exam != null) 'exam': exam,
        'count': count.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['questions'] ?? []);
    }
    throw Exception('Failed to fetch random questions: ${res.statusCode}');
  }

  Future<void> submitAttempt({
    required dynamic questionId,
    required dynamic selectedOption,
    required bool isCorrect,
    bool isSkipped = false,
    required int timeTakenSeconds,
    required String sessionId,
    required Map<String, dynamic> questionMeta,
  }) async {
    final token = await _getToken();
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/attempt/submit'),
          headers: _headers(token),
          body: jsonEncode({
            'questionId': questionId,
            'selectedOption': selectedOption,
            'isCorrect': isCorrect,
            'isSkipped': isSkipped,
            'timeTakenSeconds': timeTakenSeconds,
            'sessionId': sessionId,
            'questionMeta': questionMeta,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Submit failed: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> finishTestSession({
    required String sessionId,
    required List<Map<String, dynamic>> attempts,
  }) async {
    final token = await _getToken();
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/test/finish'),
          headers: _headers(token),
          body: jsonEncode({
            'sessionId': sessionId,
            'attempts': attempts,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Finish test failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/user/profile'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get profile: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> updates) async {
    final token = await _getToken();
    final res = await http
        .patch(
          Uri.parse('${AppConstants.baseUrl}/user/profile'),
          headers: _headers(token),
          body: jsonEncode(updates),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update profile: ${res.statusCode}');
  }

  Future<void> updateExamType(String examType) async {
    await updateUserProfile({'examType': examType});
  }

  Future<bool> checkUserIdAvailable(String userID) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/user/check-userid')
        .replace(queryParameters: {'userID': userID});

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['available'] == true;
    }
    throw Exception('Check userID failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> createOrUpdateProfile({
    required String userID,
    required String name,
    required String examType,
  }) async {
    final token = await _getToken();
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/profile'),
          headers: _headers(token),
          body: jsonEncode({
            'userID': userID,
            'name': name,
            'examType': examType,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200 || res.statusCode == 409) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 409 &&
          data['message'] == 'Profile already exists for this account') {
        await updateUserProfile({'name': name, 'examType': examType});
        return data;
      }
      if (res.statusCode == 409) {
        throw Exception(data['message'] ?? 'userID is already taken');
      }
      return data;
    }
    throw Exception('Failed to create profile: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/user/profile'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get analytics: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getOverallRank() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/user/overall-rank'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get rank: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getLeaderboard({int limit = 50}) async {
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/leaderboard/global?limit=$limit'),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get leaderboard: ${res.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getBookmarks({
    String? collection,
    int limit = 100,
    int skip = 0,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/bookmarks').replace(
      queryParameters: {
        if (collection != null) 'collection': collection,
        'limit': limit.toString(),
        'skip': skip.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['bookmarks'] ?? []);
    }
    throw Exception('Failed to get bookmarks: ${res.statusCode}');
  }

  Future<void> addBookmark({
    required dynamic questionId,
    String collection = 'pcsquestions',
  }) async {
    final token = await _getToken();
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/bookmark'),
          headers: _headers(token),
          body: jsonEncode({
            'questionId': questionId,
            'collection': collection,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 &&
        res.statusCode != 201 &&
        res.statusCode != 409) {
      throw Exception('Failed to add bookmark: ${res.statusCode}');
    }
  }

  Future<void> removeBookmark({
    required dynamic questionId,
    String collection = 'pcsquestions',
  }) async {
    final token = await _getToken();
    final res = await http
        .delete(
          Uri.parse('${AppConstants.baseUrl}/bookmark/$questionId')
              .replace(queryParameters: {'collection': collection}),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to remove bookmark: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getCurrentAffairs({
    String? subject,
    String? date,
    String? search,
    int limit = 20,
    int skip = 0,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/current-affairs').replace(
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (date != null) 'date': date,
        if (search != null) 'search': search,
        'limit': limit.toString(),
        'skip': skip.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch current affairs: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getCurrentAffairById(String id) async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/current-affairs/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch current affair: ${res.statusCode}');
  }

  Future<List<String>> getCurrentAffairsSubjects() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/current-affairs/subjects'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<String>.from(data['subjects'] ?? []);
    }
    throw Exception('Failed to fetch CA subjects: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getImportantTopics({
    String? subject,
    String? search,
    int limit = 20,
    int skip = 0,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/important-topics').replace(
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (search != null) 'search': search,
        'limit': limit.toString(),
        'skip': skip.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch important topics: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getImportantTopicById(String id) async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/important-topics/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch important topic: ${res.statusCode}');
  }

  Future<List<String>> getImportantTopicsSubjects() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/important-topics/subjects'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<String>.from(data['subjects'] ?? []);
    }
    throw Exception('Failed to fetch IT subjects: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getDidYouKnow({
    String? subject,
    String? search,
    int limit = 20,
    int skip = 0,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/did-you-know').replace(
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (search != null) 'search': search,
        'limit': limit.toString(),
        'skip': skip.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch did you know: ${res.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getRandomDidYouKnow({
    String? subject,
    int count = 1,
  }) async {
    final token = await _getToken();
    final uri =
        Uri.parse('${AppConstants.baseUrl}/did-you-know/random').replace(
      queryParameters: {
        if (subject != null) 'subject': subject,
        'count': count.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    throw Exception('Failed to fetch random did you know: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getDidYouKnowById(String id) async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/did-you-know/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch did you know item: ${res.statusCode}');
  }

  Future<List<String>> getDidYouKnowSubjects() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/did-you-know/subjects'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<String>.from(data['subjects'] ?? []);
    }
    throw Exception('Failed to fetch DYK subjects: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getTodayInPast({
    String? subject,
    String? date,
    String? search,
    int limit = 20,
    int skip = 0,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/today-in-past').replace(
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (date != null) 'date': date,
        if (search != null) 'search': search,
        'limit': limit.toString(),
        'skip': skip.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch today in past: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getTodayInPastToday() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/today-in-past/today'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch today in past (today): ${res.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getRandomTodayInPast({
    String? subject,
    int count = 5,
  }) async {
    final token = await _getToken();
    final uri =
        Uri.parse('${AppConstants.baseUrl}/today-in-past/random').replace(
      queryParameters: {
        if (subject != null) 'subject': subject,
        'count': count.toString(),
      },
    );

    final res = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    }
    throw Exception('Failed to fetch random today in past: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getTodayInPastById(String id) async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/today-in-past/$id'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch today in past item: ${res.statusCode}');
  }

  Future<List<String>> getTodayInPastSubjects() async {
    final token = await _getToken();
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/today-in-past/subjects'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return List<String>.from(data['subjects'] ?? []);
    }
    throw Exception('Failed to fetch TIP subjects: ${res.statusCode}');
  }
}
