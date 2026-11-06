import 'package:flutter/material.dart';

class _TutorialPage {
  final String title;
  final String emoji;
  final String image;
  final String goal;
  final List<String> steps;
  final String difficultyNote;

  const _TutorialPage({
    required this.title,
    required this.emoji,
    required this.image,
    required this.goal,
    required this.steps,
    required this.difficultyNote,
  });
}

const List<_TutorialPage> _pages = [
  _TutorialPage(
    title: 'LEVEL 1: MATH CHALLENGE',
    emoji: '🔢',
    image: 'assets/images/how_to_play/level_1.png',
    goal: 'Answer 10 math questions correctly.',
    steps: [
      'Read the question at the top of the screen.',
      'Type your answer in the box.',
      'Press SUBMIT (or the keyboard check) to lock it in.',
      'Answer correctly in a row to build a streak. Every 3rd correct answer gives bonus XP!',
      'Get 60% or more correct to pass.',
    ],
    difficultyNote:
        'Easy: + and − with no timer. Medium: adds ×, 10 seconds per question. Hard: adds ÷.',
  ),
  _TutorialPage(
    title: 'LEVEL 2: SCIENCE PUZZLE',
    emoji: '🧩',
    image: 'assets/images/how_to_play/level_2.png',
    goal: 'Rebuild the science picture.',
    steps: [
      'Memorize the full picture while it is shown.',
      'The picture breaks into pieces and gets scrambled.',
      'Tap one piece, then tap another to swap them.',
      'Keep swapping until the picture is back to normal.',
      'Fewer moves and faster time give a higher score.',
    ],
    difficultyNote:
        'Easy: 3×3, no timer. Medium: 3×3, 60 seconds. Hard: 4×4, 45 seconds.',
  ),
  _TutorialPage(
    title: 'LEVEL 3: MEMORY MATCH',
    emoji: '🧠',
    image: 'assets/images/how_to_play/level_3.png',
    goal: 'Find all the matching pairs.',
    steps: [
      'All cards are shown for a few seconds. Remember where each symbol is!',
      'The cards flip face down.',
      'Tap two cards to reveal them.',
      'If they match, they stay open. If not, they flip back.',
      'Match every pair to finish the level.',
    ],
    difficultyNote:
        'Easy: 6 pairs, no timer. Medium: 6 pairs, 60 seconds. Hard: 8 pairs, 45 seconds.',
  ),
  _TutorialPage(
    title: 'LEVEL 4: PATTERN LOGIC',
    emoji: '🔮',
    image: 'assets/images/how_to_play/level_4.png',
    goal: 'Find what comes next in each pattern.',
    steps: [
      'Look at the pattern of numbers or shapes.',
      'Figure out the rule (adding, multiplying, repeating...).',
      'Tap the answer that continues the pattern.',
      'Green means correct, red means wrong, and the right answer is shown.',
      'Get 60% or more correct to pass.',
    ],
    difficultyNote:
        'Easy: 5 questions, no timer. Medium: 7 questions, 15 seconds each. Hard: 10 questions, 10 seconds each.',
  ),
  _TutorialPage(
    title: 'LEVEL 5: TILE MATRIX',
    emoji: '⭐',
    image: 'assets/images/how_to_play/level_5.png',
    goal: 'Remember where the glowing stars were.',
    steps: [
      'Watch the grid. Some tiles glow with stars.',
      'The stars disappear after a few seconds.',
      'Tap the tiles where the stars were.',
      'A wrong tile costs you time and gives you a new pattern.',
      'Each round adds more stars and a bigger grid.',
    ],
    difficultyNote:
        'Easy: 5 rounds, no timer. Medium: 7 rounds, 30 seconds. Hard: 10 rounds, 20 seconds. Correct rounds add bonus seconds!',
  ),
  _TutorialPage(
    title: 'LEVEL 6: CASE DETECTIVE',
    emoji: '🕵️',
    image: 'assets/images/how_to_play/level_6.png',
    goal: 'Solve the mystery case.',
    steps: [
      'Read the story of the mystery.',
      'Tap the picture to inspect it closely. Pinch to zoom!',
      'Read all the evidence and clues.',
      'Choose the answer the evidence points to.',
      'Read the explanation to see why it was right.',
    ],
    difficultyNote:
        'Easy: no timer. Medium: 50 seconds. Hard: 20 seconds, and more XP for a correct answer.',
  ),
  _TutorialPage(
    title: 'LEVEL 7: WORD QUEST',
    emoji: '🖼️',
    image: 'assets/images/how_to_play/level_7.png',
    goal: 'Guess the one word that connects 4 pictures.',
    steps: [
      'Look at the 4 pictures. Tap one to zoom in.',
      'Think of the word they all share. Read the clue if you need help.',
      'Tap letters from the letter bank to fill the answer boxes.',
      'Tap a filled box to remove a letter.',
      'Stuck? Use a hint to reveal one correct letter.',
    ],
    difficultyNote:
        'Easy: 5 words, 5 hints, no timer. Medium: 7 words, 3 hints, 30 seconds. Hard: 10 words, 1 hint, 10 seconds.',
  ),
  _TutorialPage(
    title: 'LEVEL 8: PATH FINDER',
    emoji: '🧭',
    image: 'assets/images/how_to_play/level_8.png',
    goal: 'Remember the maze and trace the path.',
    steps: [
      'Memorize the maze and the route from START (S) to FINISH (F).',
      'The maze hides after a few seconds.',
      'Drag your finger from S through the corridors to F.',
      'Hitting a wall costs a life, and the maze is shown again.',
      'You have 3 lives. Finish every maze to win!',
    ],
    difficultyNote:
        'Easy and Medium: 3 mazes. Hard: 5 mazes. Later mazes are bigger.',
  ),
];

class HowToPlayScreen extends StatefulWidget {
  /// Optional: open on a specific level (0 = Level 1).
  final int initialPage;

  const HowToPlayScreen({super.key, this.initialPage = 0});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPage.clamp(0, _pages.length - 1);
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirst = _current == 0;
    final bool isLast = _current == _pages.length - 1;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const Expanded(
                      child: Text(
                        'HOW TO PLAY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, index) =>
                      _buildPage(_pages[index]),
                ),
              ),

              // Dots
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final bool active = i == _current;
                    return GestureDetector(
                      onTap: () => _go(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFFFD700) : Colors.white30,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _navButton(
                        label: 'Previous',
                        icon: Icons.arrow_back_rounded,
                        color: const Color(0xFF9B8AD6),
                        enabled: !isFirst,
                        onPressed: () => _go(_current - 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _navButton(
                        label: isLast ? 'Done' : 'Next',
                        icon: isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        color: const Color(0xFFFFD700),
                        textColor: const Color(0xFF3B0B46),
                        iconAfterText: !isLast,
                        onPressed: () =>
                            isLast ? Navigator.pop(context) : _go(_current + 1),
                      ),
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

  Widget _buildPage(_TutorialPage page) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Title pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
            ),
            child: Text(
              '${page.emoji}  ${page.title}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Screenshot
          _buildScreenshot(page.image),
          const SizedBox(height: 14),

          // Goal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    page.goal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Steps
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < page.steps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == page.steps.length - 1 ? 0 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Color(0xFF4A0E4E),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            page.steps[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Difficulty note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.speed_rounded,
                    color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    page.difficultyNote,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildScreenshot(String path) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          height: 180,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 48, color: Colors.white54),
              SizedBox(height: 8),
              Text(
                'Screenshot coming soon',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color textColor = Colors.white,
    bool enabled = true,
    bool iconAfterText = false,
  }) {
    final iconWidget = Icon(icon, color: textColor, size: 20);
    final textWidget = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconAfterText
                ? [textWidget, const SizedBox(width: 8), iconWidget]
                : [iconWidget, const SizedBox(width: 8), textWidget],
          ),
        ),
      ),
    );
  }
}