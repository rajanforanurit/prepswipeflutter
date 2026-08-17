// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:prepswipe/utils/constants.dart'; // Ensure firebase_auth is in pubspec.yaml

// class CommunityApiService {
//   // Replace with your actual backend URL
//   static const String baseUrl = AppConstants.baseUrl;

//   Future<Map<String, String>> _getHeaders() async {
//     final User? user = FirebaseAuth.instance.currentUser;
//     final String? token = await user?.getIdToken();
//     return {
//       "Content-Type": "application/json",
//       "Authorization": "Bearer $token",
//     };
//   }

//   // Fetch Public Challenges
//   Future<Map<String, dynamic>> fetchPublicChallenges(
//       {String? exam, String? subject, String? search, int page = 1}) async {
//     print("loading public challanges");
//     final headers = await _getHeaders();
//     String query = "?page=$page";
//     if (exam != null) query += "&exam=$exam";
//     if (subject != null) query += "&subject=$subject";
//     if (search != null) query += "&search=$search";

//     final response = await http
//         .get(Uri.parse("$baseUrl/community/public$query"), headers: headers);
//     print(response.body);
//     return jsonDecode(response.body);
//   }

//   // Fetch My Challenges
//   Future<Map<String, dynamic>> fetchMyChallenges() async {
//     final headers = await _getHeaders();
//     final response =
//         await http.get(Uri.parse("$baseUrl/community/my"), headers: headers);
//     return jsonDecode(response.body);
//   }

//   // Create Challenge
//   Future<Map<String, dynamic>> createChallenge(
//       Map<String, dynamic> challengeData) async {
//     print("creating challange");
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse("$baseUrl/community/create"),
//       headers: headers,
//       body: jsonEncode(challengeData),
//     );
//     print(response.body);
//     return jsonDecode(response.body);
//   }

//   // Join Challenge
//   Future<Map<String, dynamic>> joinChallenge(String roomId,
//       {String? password}) async {
//     final headers = await _getHeaders();
//     final body = password != null ? jsonEncode({"password": password}) : null;
//     final response = await http.post(
//       Uri.parse("$baseUrl/community/$roomId/join"),
//       headers: headers,
//       body: body,
//     );
//     return jsonDecode(response.body);
//   }

//   // Get Room Details
//   Future<Map<String, dynamic>> fetchRoomDetails(String id) async {
//     final headers = await _getHeaders();
//     final response =
//         await http.get(Uri.parse("$baseUrl/community/$id"), headers: headers);
//     return jsonDecode(response.body);
//   }

//   // Start Challenge (Owner only)
//   Future<Map<String, dynamic>> startChallenge(String id) async {
//     final headers = await _getHeaders();
//     final response = await http.post(Uri.parse("$baseUrl/community/$id/start"),
//         headers: headers);
//     return jsonDecode(response.body);
//   }

//   // Start Individual Attempt (Timer Trigger)
//   Future<Map<String, dynamic>> startAttempt(String id) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//         Uri.parse("$baseUrl/community/$id/start-attempt"),
//         headers: headers);
//     return jsonDecode(response.body);
//   }

//   // Get Challenge Questions
//   Future<Map<String, dynamic>> fetchChallengeQuestions(String id) async {
//     final headers = await _getHeaders();
//     final response = await http
//         .get(Uri.parse("$baseUrl/community/$id/questions"), headers: headers);
//     return jsonDecode(response.body);
//   }

//   // Update Live Progress
//   Future<Map<String, dynamic>> updateProgress(
//       String id, int currentQuestionIndex) async {
//     final headers = await _getHeaders();
//     final response = await http.patch(
//       Uri.parse("$baseUrl/community/$id/progress"),
//       headers: headers,
//       body: jsonEncode({"currentQuestionIndex": currentQuestionIndex}),
//     );
//     return jsonDecode(response.body);
//   }

//   // Finish Challenge and submit answers
//   Future<Map<String, dynamic>> finishChallenge(String id,
//       List<Map<String, dynamic>> answers, int totalTimeSeconds) async {
//     final headers = await _getHeaders();
//     final response = await http.post(
//       Uri.parse("$baseUrl/community/$id/finish"),
//       headers: headers,
//       body: jsonEncode({
//         "answers": answers,
//         "totalTimeSeconds": totalTimeSeconds,
//       }),
//     );
//     return jsonDecode(response.body);
//   }

//   // Fetch Live Leaderboard
//   Future<Map<String, dynamic>> fetchLeaderboard(String id) async {
//     final headers = await _getHeaders();
//     final response = await http
//         .get(Uri.parse("$baseUrl/community/$id/leaderboard"), headers: headers);
//     return jsonDecode(response.body);
//   }

//   // Search Questions for Manual Select
//   Future<Map<String, dynamic>> searchManualQuestions(
//       {required String exam,
//       required String subject,
//       String? topic,
//       String? search}) async {
//     final headers = await _getHeaders();
//     String query = "?exam=$exam&subject=$subject";
//     if (topic != null) query += "&topic=$topic";
//     if (search != null) query += "&search=$search";

//     final response = await http.get(
//         Uri.parse("$baseUrl/community/questions/search$query"),
//         headers: headers);
//     return jsonDecode(response.body);
//   }
// }
