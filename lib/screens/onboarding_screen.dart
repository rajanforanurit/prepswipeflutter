import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  String? _selectedExam;

  bool _checkingUserId = false;
  bool _userIdAvailable = false;
  bool _userIdChecked = false;
  String? _userIdError;
  bool _saving = false;
  String? _saveError;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _prefillFromFirebase();
  }

  void _prefillFromFirebase() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final displayName = firebaseUser.displayName ?? '';
    _nameController.text = displayName;

    final cleanBase = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final base = cleanBase.isNotEmpty
        ? cleanBase.substring(0, cleanBase.length > 10 ? 10 : cleanBase.length)
        : 'user';

    final suffix =
        (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
    final suggested = '$base$suffix';
    _userIdController.text =
        suggested.length > 20 ? suggested.substring(0, 20) : suggested;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _checkUserIdAvailability(String value) async {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _userIdChecked = false;
        _userIdAvailable = false;
        _userIdError = null;
      });
      return;
    }

    final regex = RegExp(r'^[a-z0-9_]{4,20}$');
    if (!regex.hasMatch(trimmed)) {
      setState(() {
        _userIdChecked = true;
        _userIdAvailable = false;
        _userIdError =
            'Use 4–20 chars: lowercase letters, numbers, underscore only.';
      });
      return;
    }

    setState(() {
      _checkingUserId = true;
      _userIdError = null;
      _userIdChecked = false;
    });

    try {
      final available = await _api.checkUserIdAvailable(trimmed);
      if (mounted) {
        setState(() {
          _checkingUserId = false;
          _userIdChecked = true;
          _userIdAvailable = available;
          _userIdError =
              available ? null : 'This ID is already taken. Try another.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingUserId = false;
          _userIdChecked = false;
          _userIdError = 'Could not verify. You can still proceed.';
        });
      }
    }
  }

  bool get _canProceedFromStep1 {
    final name = _nameController.text.trim();
    final userID = _userIdController.text.trim().toLowerCase();
    if (name.isEmpty) return false;
    if (userID.length < 4) return false;
    if (_checkingUserId) return false;
    if (_userIdChecked && !_userIdAvailable) return false;
    return true;
  }

  bool get _canProceedFromStep2 => _selectedExam != null;

  void _nextPage() {
    if (_currentPage < 1) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final userID = _userIdController.text.trim().toLowerCase();
    final exam = _selectedExam!;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await _api.createOrUpdateProfile(
        userID: userID,
        name: name,
        examType: exam,
      );
      if (mounted) await widget.onCompleted();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(currentPage: _currentPage),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _Step1Identity(
                    nameController: _nameController,
                    userIdController: _userIdController,
                    checkingUserId: _checkingUserId,
                    userIdAvailable: _userIdAvailable,
                    userIdChecked: _userIdChecked,
                    userIdError: _userIdError,
                    onUserIdChanged: (val) {
                      setState(() {
                        _userIdChecked = false;
                        _userIdAvailable = false;
                        _userIdError = null;
                      });
                      if (val.trim().length >= 4) {
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted &&
                              _userIdController.text.trim().toLowerCase() ==
                                  val.trim().toLowerCase()) {
                            _checkUserIdAvailability(val);
                          }
                        });
                      }
                    },
                  ),
                  _Step2Exam(
                    selectedExam: _selectedExam,
                    onExamSelected: (val) =>
                        setState(() => _selectedExam = val),
                    saveError: _saveError,
                  ),
                ],
              ),
            ),
            _OnboardingFooter(
              currentPage: _currentPage,
              canProceed: _currentPage == 0
                  ? _canProceedFromStep1
                  : _canProceedFromStep2,
              saving: _saving,
              onNext: _currentPage == 0 ? _nextPage : _completeOnboarding,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  final int currentPage;
  const _OnboardingHeader({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Prep',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'Swipe',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Step ${currentPage + 1} of 2',
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(2, (i) {
              final active = i <= currentPage;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Step1Identity extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController userIdController;
  final bool checkingUserId;
  final bool userIdAvailable;
  final bool userIdChecked;
  final String? userIdError;
  final ValueChanged<String> onUserIdChanged;

  const _Step1Identity({
    required this.nameController,
    required this.userIdController,
    required this.checkingUserId,
    required this.userIdAvailable,
    required this.userIdChecked,
    required this.userIdError,
    required this.onUserIdChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set up your\nprofile',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose how you appear to other users on the platform.',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          const _FieldLabel(label: 'Your Name'),
          const SizedBox(height: 8),
          _InputField(
            controller: nameController,
            hint: 'e.g. Rajan Singh',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 24),
          const _FieldLabel(label: 'Choose a User ID'),
          const SizedBox(height: 8),
          _UserIdField(
            controller: userIdController,
            checkingUserId: checkingUserId,
            userIdAvailable: userIdAvailable,
            userIdChecked: userIdChecked,
            onChanged: onUserIdChanged,
          ),
          const SizedBox(height: 6),
          if (userIdError != null)
            _StatusText(text: userIdError!, color: AppColors.red)
          else if (userIdChecked && userIdAvailable)
            const _StatusText(
                text: '✓ This ID is available!', color: AppColors.green)
          else
            const Text(
              'Lowercase letters, numbers, underscore. Min 4 characters.',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.accent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The User ID you choose here is what everyone sees on the leaderboard.',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step2Exam extends StatelessWidget {
  final String? selectedExam;
  final ValueChanged<String?> onExamSelected;
  final String? saveError;

  const _Step2Exam({
    required this.selectedExam,
    required this.onExamSelected,
    required this.saveError,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick your\ntarget exam',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We will personalise questions and content based on your exam.',
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ...AppConstants.examTypes.map((exam) {
            final selected = selectedExam == exam;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onExamSelected(exam),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.cardBorder,
                      width: selected ? 1.8 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accent
                              : AppColors.surfaceSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color:
                              selected ? Colors.white : AppColors.textTertiary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        exam,
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (saveError != null) ...[
            const SizedBox(height: 16),
            _StatusText(text: saveError!, color: AppColors.red),
          ],
        ],
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  final int currentPage;
  final bool canProceed;
  final bool saving;
  final VoidCallback onNext;

  const _OnboardingFooter({
    required this.currentPage,
    required this.canProceed,
    required this.saving,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = currentPage == 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: (canProceed && !saving) ? onNext : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              color: canProceed ? AppColors.accent : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: canProceed
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isLastStep ? 'Start Learning →' : 'Continue →',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color:
                            canProceed ? Colors.white : AppColors.textTertiary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 14,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon:
              Icon(prefixIcon, color: AppColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _UserIdField extends StatelessWidget {
  final TextEditingController controller;
  final bool checkingUserId;
  final bool userIdAvailable;
  final bool userIdChecked;
  final ValueChanged<String> onChanged;

  const _UserIdField({
    required this.controller,
    required this.checkingUserId,
    required this.userIdAvailable,
    required this.userIdChecked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget? suffixWidget;
    if (checkingUserId) {
      suffixWidget = const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    } else if (userIdChecked) {
      suffixWidget = Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(
          userIdAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: userIdAvailable ? AppColors.green : AppColors.red,
          size: 20,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: userIdChecked
              ? (userIdAvailable ? AppColors.green : AppColors.red)
              : AppColors.cardBorder,
          width: userIdChecked ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
          LengthLimitingTextInputFormatter(20),
        ],
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'e.g. rajan_upsc or uppcs123',
          hintStyle: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 14,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(Icons.alternate_email_rounded,
              color: AppColors.textSecondary, size: 20),
          suffixIcon: suffixWidget,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}
