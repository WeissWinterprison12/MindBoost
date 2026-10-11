import 'package:flutter/material.dart';

import '../game/math_game.dart';
import '../game/science_puzzle.dart';
import '../game/memory_match.dart';
import '../game/pattern_logic.dart';
import '../game/sequence.dart';
import '../game/memory_matrix.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A0E4E), // Rich Violet
              Color(0xFF811252), // Deep Magenta
              Color(0xFF2E0854), // Dark Cosmic Purple
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // TOP BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // BACK BUTTON
                    _build3DButton(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                    // HEADER TITLE BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 2,
                        ),
                      ),
                      child: const Text(
                        "LEVEL SELECT",
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    // COIN / STAR COUNTER BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            offset: Offset(0, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 4),
                          Text(
                            "18/18",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // LOGO HEADER
              const SizedBox(height: 5),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFFF176), Color(0xFFFF8A65)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Text(
                  "🧠 MindBoost",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(2, 4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),

              const Text(
                "Pick your puzzle arena!",
                style: TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 15),

              // GAME GRID LIST
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    GameLevelCard(
                      levelNum: "1",
                      title: "Math Challenge",
                      subtitle: "Speed & Accuracy",
                      icon: "🔢",
                      gradientColors: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      borderColor: const Color(0xFF0052B4),
                      starsEarned: 3,
                      unlocked: true,
                      page: const MathGame(),
                    ),
                    GameLevelCard(
                      levelNum: "2",
                      title: "Science Puzzle",
                      subtitle: "Memory & Observation",
                      icon: "🔬",
                      gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                      borderColor: const Color(0xFF0C6B63),
                      starsEarned: 3,
                      unlocked: true,
                      page: const SciencePuzzle(),
                    ),
                    GameLevelCard(
                      levelNum: "3",
                      title: "Memory Match",
                      subtitle: "Focus & Attention",
                      icon: "🧩",
                      gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      borderColor: const Color(0xFF330099),
                      starsEarned: 3,
                      unlocked: true,
                      page: const MemoryMatch(),
                    ),
                    GameLevelCard(
                      levelNum: "4",
                      title: "Pattern Logic",
                      subtitle: "Logical Reasoning",
                      icon: "🧠",
                      gradientColors: const [Color(0xFFFF8008), Color(0xFFFFC837)],
                      borderColor: const Color(0xFFC76000),
                      starsEarned: 2,
                      unlocked: true,
                      page: const PatternLogic(),
                    ),
                    GameLevelCard(
                      levelNum: "5",
                      title: "Sequence Recall",
                      subtitle: "Repeat the Order",
                      icon: "🔄",
                      gradientColors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                      borderColor: const Color(0xFFB31217),
                      starsEarned: 1,
                      unlocked: true,
                      page: const SequenceRecall(),
                    ),
                    GameLevelCard(
                      levelNum: "6",
                      title: "Memory Matrix",
                      subtitle: "Find the Mismatch",
                      icon: "🎯",
                      gradientColors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
                      borderColor: const Color(0xFFB86B00),
                      starsEarned: 0,
                      unlocked: true,
                      page: const MemoryMatrix(),
                    ),
                    const LockedLevelCard(
                      levelNum: "7",
                      title: "Coming Soon",
                      subtitle: "Unlock Level 6 first!",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _build3DButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF4081),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF990033),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GameLevelCard extends StatefulWidget {
  final String levelNum;
  final String title;
  final String subtitle;
  final String icon;
  final List<Color> gradientColors;
  final Color borderColor;
  final int starsEarned;
  final bool unlocked;
  final Widget page;

  const GameLevelCard({
    super.key,
    required this.levelNum,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.borderColor,
    required this.starsEarned,
    required this.unlocked,
    required this.page,
  });

  @override
  State<GameLevelCard> createState() => _GameLevelCardState();
}

class _GameLevelCardState extends State<GameLevelCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => widget.page),
        );
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 18),
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: widget.borderColor,
              offset: Offset(0, _isPressed ? 2 : 7),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 8),
              blurRadius: 10,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // LEVEL BADGE + EMOJI AVATAR
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.icon,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // CARD DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEVEL NUMBER TAG
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "LEVEL ${widget.levelNum}",
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(1, 2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),

                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // STAR RATING DISPLAY
                    Row(
                      children: List.generate(3, (index) {
                        return Icon(
                          index < widget.starsEarned
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < widget.starsEarned
                              ? const Color(0xFFFFD700)
                              : Colors.white54,
                          size: 20,
                        );
                      }),
                    ),
                  ],
                ),
              ),

              // PLAY BUTTON ICON
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.borderColor,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: widget.borderColor,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LockedLevelCard extends StatelessWidget {
  final String levelNum;
  final String title;
  final String subtitle;

  const LockedLevelCard({
    super.key,
    required this.levelNum,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.lock_rounded,
                color: Colors.white54,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LEVEL $levelNum",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
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