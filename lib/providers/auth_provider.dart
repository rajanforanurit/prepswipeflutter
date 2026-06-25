import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _api = ApiService();

  User? _firebaseUser;
  UserProfile? _userProfile;

  bool _isLoading = true;
  bool _signingIn = false;

  User? get user => _firebaseUser;
  UserProfile? get userProfile => _userProfile;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isLoading => _isLoading;
  bool get isSigningIn => _signingIn;

  String get displayName {
    if (_userProfile?.displayName?.isNotEmpty ?? false) {
      return _userProfile!.displayName!;
    }
    if (_firebaseUser?.displayName?.isNotEmpty ?? false) {
      return _firebaseUser!.displayName!;
    }
    if (_userProfile?.userID?.isNotEmpty ?? false) return _userProfile!.userID!;
    return 'Learner';
  }

  String get displayUserId {
    if (_userProfile?.userID?.isNotEmpty ?? false) return _userProfile!.userID!;
    if (_firebaseUser?.email?.isNotEmpty ?? false) return _firebaseUser!.email!;
    return '';
  }

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _firebaseUser = firebaseUser;
    if (firebaseUser != null) {
      await _fetchProfile();
    } else {
      _userProfile = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await _api.getUserProfile();
      _userProfile = UserProfile.fromJson(data);
    } catch (_) {}
  }

  Future<bool> signInWithGoogle(BuildContext context) async {
    _signingIn = true;
    notifyListeners();
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _signingIn = false;
        notifyListeners();
        return false;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      _signingIn = false;
      notifyListeners();
      rethrow;
    } finally {
      _signingIn = false;
      notifyListeners();
    }
  }

  Future<void> updateExamType(String examType) async {
    await _api.updateExamType(examType);
    await _fetchProfile();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _fetchProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _userProfile = null;
    notifyListeners();
  }
}
