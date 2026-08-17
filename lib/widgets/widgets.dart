import 'package:flutter/material.dart';
import 'package:prepswipe/models/question_model.dart';
import 'package:prepswipe/screens/revision_screen.dart';

class LanguageToggle extends StatelessWidget {
  final AppLanguage language;
  final VoidCallback onTap;

  const LanguageToggle(
      {super.key, required this.language, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHindi = language == AppLanguage.hindi;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: RevisionColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.translate_rounded,
              color: RevisionColors.textSecondary,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              isHindi ? 'हिंदी' : 'English',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: RevisionColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}