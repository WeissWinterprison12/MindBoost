
import 'package:flutter/material.dart';
import '../models/game_difficulty.dart';

class DifficultySelection {
  static Future<GameDifficulty?> show(BuildContext context) {
    return showDialog<GameDifficulty>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _DifficultyDialog(),
    );
  }
}

class _DifficultyDialog extends StatelessWidget {
  const _DifficultyDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4A0E4E),
              Color(0xFF811252),
              Color(0xFF2E0854),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFFFD700),
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SELECT DIFFICULTY',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your challenge before starting!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            _difficultyButton(
              context,
              difficulty: GameDifficulty.easy,
              subtitle: 'Relaxed gameplay',
              color: const Color(0xFF38EF7D),
              shadowColor: const Color(0xFF0C6B63),
              textColor: const Color(0xFF003816),
            ),
            const SizedBox(height: 13),

            _difficultyButton(
              context,
              difficulty: GameDifficulty.medium,
              subtitle: 'A balanced challenge',
              color: const Color(0xFFFFD166),
              shadowColor: const Color(0xFFB8860B),
              textColor: const Color(0xFF4A2800),
            ),
            const SizedBox(height: 13),

            _difficultyButton(
              context,
              difficulty: GameDifficulty.hard,
              subtitle: 'Test your skills',
              color: const Color(0xFFFF6B6B),
              shadowColor: const Color(0xFF9E2929),
              textColor: Colors.white,
            ),

            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyButton(
    BuildContext context, {
    required GameDifficulty difficulty,
    required String subtitle,
    required Color color,
    required Color shadowColor,
    required Color textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context, difficulty),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 5,
          shadowColor: shadowColor,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Column(
          children: [
            Text(
              difficulty.label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
