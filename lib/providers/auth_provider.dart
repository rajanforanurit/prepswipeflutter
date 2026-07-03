import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _api = ApiService();

  late final Razorpay _razorpay;

  bool _subscriptionLoading = false;
  bool _purchaseLoading = false;
  bool _isPremium = false;
  String? _subscriptionStatus;
  DateTime? _premiumExpiry;
  String? _razorpayKey;
  String? _razorpaySubscriptionId;
  User? _firebaseUser;
  UserProfile? _userProfile;

  bool _isLoading = true;
  bool _signingIn = false;

  User? get user => _firebaseUser;
  UserProfile? get userProfile => _userProfile;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isLoading => _isLoading;
  bool get isSigningIn => _signingIn;

  bool get isPremium => _isPremium;
  bool get subscriptionLoading => _subscriptionLoading;
  bool get purchaseLoading => _purchaseLoading;
  String? get subscriptionStatus => _subscriptionStatus;
  String? get razorpayKey => _razorpayKey;
  String? get razorpaySubscriptionId => _razorpaySubscriptionId;
  DateTime? get premiumExpiry => _premiumExpiry;
  bool get hasActiveSubscription => _subscriptionStatus == "active";

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
    _razorpay = Razorpay();

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handlePaymentError,
    );

    _razorpay.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );

    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  VoidCallback? _onPremiumActivated;

  void setPremiumActivatedListener(VoidCallback callback) {
    _onPremiumActivated = callback;
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _firebaseUser = firebaseUser;
    if (firebaseUser != null) {
      await _fetchProfile();

      await _loadSubscription();
    } else {
      _userProfile = null;

      _isPremium = false;
      _subscriptionStatus = null;
      _premiumExpiry = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await _api.getUserProfile();
      _userProfile = UserProfile.fromJson(data);

      notifyListeners();
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
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

    _isPremium = false;
    _subscriptionStatus = null;
    _premiumExpiry = null;

    notifyListeners();
  }

  Future<void> _loadSubscription() async {
    try {
      _subscriptionLoading = true;
      notifyListeners();

      final data = await _api.getSubscriptionStatus();

      _isPremium = data["premium"] == true;

      _subscriptionStatus = data["status"];

      final expiry = data["expiry"];

      _premiumExpiry =
          expiry != null ? DateTime.tryParse(expiry.toString()) : null;

      notifyListeners();
    } catch (e) {
      debugPrint("Load Subscription Error: $e");
    } finally {
      _subscriptionLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshSubscription() async {
    try {
      _subscriptionLoading = true;
      notifyListeners();

      await _api.refreshSubscription();

      await _loadSubscription();
    } catch (e) {
      debugPrint("Refresh Subscription Error: $e");
    } finally {
      _subscriptionLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSubscription() async {
    await _refreshSubscription();
  }

  Future<void> purchase() async {
    try {
      _purchaseLoading = true;
      notifyListeners();

      final data = await _api.createSubscription();

      final subscriptionId = data["subscriptionId"];

      final razorpayKey = data["key"];

      _razorpaySubscriptionId = subscriptionId;

      final options = {
        "key": razorpayKey,
        "subscription_id": subscriptionId,
        "name": "PrepSwipe",
        "description": "PrepSwipe Premium",
        "prefill": {
          "name": displayName,
          "email": user?.email ?? "",
          "contact": "",
        },
        "theme": {
          "color": "#4F46E5",
        },
      };

      _razorpay.open(options);
    } catch (e) {
      _purchaseLoading = false;

      _razorpaySubscriptionId = null;

      notifyListeners();

      debugPrint("Purchase Error : $e");
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      _purchaseLoading = true;
      notifyListeners();

      await _api.verifySubscription(
        paymentId: response.paymentId ?? "",
        subscriptionId: _razorpaySubscriptionId ?? "",
        signature: response.signature ?? "",
      );

      await _refreshSubscription();

      if (_isPremium) {
        _onPremiumActivated?.call();
      }
    } catch (e) {
      debugPrint("Payment Success Error: $e");
    } finally {
      _purchaseLoading = false;
      notifyListeners();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _purchaseLoading = false;

    notifyListeners();

    debugPrint(
      "Payment Failed : ${response.code} ${response.message}",
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint(
      "External Wallet : ${response.walletName}",
    );
  }

  @override
  void dispose() {
    _razorpay.clear();

    super.dispose();
  }
}
