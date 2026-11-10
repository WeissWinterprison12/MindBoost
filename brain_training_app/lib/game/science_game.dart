import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/game_difficulty.dart';
import 'science_puzzle.dart';
import '../services/game_audio.dart';
import '../services/game_options_menu.dart';
import '../widgets/pause_menu.dart';
import '../services/score_identity.dart';
// ============================================================
// CHALLENGE MODEL
// ============================================================

class ScienceQuestion {
  final String letter;
  final String description;
  final String answer;

  // Normalized marker position on the illustration (0.0 to 1.0).
  final double markerX;
  final double markerY;

  const ScienceQuestion({
    required this.letter,
    required this.description,
    required this.answer,
    required this.markerX,
    required this.markerY,
  });
}

class ScienceChallenge {
  final String category;
  final String title;
  final String image;

  // Every challenge now holds 5 questions (A to E).
  // Easy uses the first 3, Medium the first 4, Hard all 5.
  final List<ScienceQuestion> questions;

  const ScienceChallenge({
    required this.category,
    required this.title,
    required this.image,
    required this.questions,
  });
}

// ============================================================
// SCIENCE GAME
// ============================================================

class ScienceGame extends StatefulWidget {
  final GameDifficulty difficulty;

  const ScienceGame({
    super.key,
    this.difficulty = GameDifficulty.hard,
  });

  @override
  State<ScienceGame> createState() => _ScienceGameState();
}

class _ScienceGameState extends State<ScienceGame>
    with TickerProviderStateMixin {

  // ============================================================
  // GAME SETTINGS
  // ============================================================

  // EASY   = no timer,  3 things to answer
  // MEDIUM = 50 seconds, 4 things to answer
  // HARD   = 30 seconds, 5 things to answer

  int get totalGameDuration {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 0;
      case GameDifficulty.medium:
        return 50;
      case GameDifficulty.hard:
        return 30;
    }
  }

  int get questionCount {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 3;
      case GameDifficulty.medium:
        return 4;
      case GameDifficulty.hard:
        return 5;
    }
  }

  bool get hasGameTimer =>
      widget.difficulty != GameDifficulty.easy;

  // ============================================================
  // CHALLENGES
  // ============================================================

  final List<ScienceChallenge> challenges = const [

    // ----------------------------------------------------------
    // BIOLOGY 1: MAJOR HUMAN BODY ORGANS
    // ----------------------------------------------------------

    ScienceChallenge(
      category: 'BIOLOGY',
      title: 'HUMAN BODY',
      image: 'assets/images/science_game/biology_body.png',
      questions: [
        ScienceQuestion(
          letter: 'A',
          description: 'This is where the air we breathe goes.',
          answer: 'LUNGS',
          markerX: 0.50,
          markerY: 0.37,
        ),
        ScienceQuestion(
          letter: 'B',
          description: 'This is where air enters the body.',
          answer: 'NOSE',
          markerX: 0.50,
          markerY: 0.12,
        ),
        ScienceQuestion(
          letter: 'C',
          description:
              'This organ processes nutrients and helps remove harmful substances.',
          answer: 'LIVER',
          markerX: 0.39,
          markerY: 0.54,
        ),
        ScienceQuestion(
          letter: 'D',
          description: 'This organ pumps blood throughout the body.',
          answer: 'HEART',
          markerX: 0.53,
          markerY: 0.43,
        ),
        // NEW (5th question) - adjust the marker to match your image.
        ScienceQuestion(
          letter: 'E',
          description: 'This organ breaks down food after we swallow it.',
          answer: 'STOMACH',
          markerX: 0.58,
          markerY: 0.56,
        ),
      ],
    ),

    // ----------------------------------------------------------
    // BIOLOGY 2: RESPIRATORY SYSTEM
    // ----------------------------------------------------------

    ScienceChallenge(
      category: 'BIOLOGY',
      title: 'RESPIRATORY SYSTEM',
      image: 'assets/images/science_game/biology_respiratory.png',
      questions: [
        ScienceQuestion(
          letter: 'A',
          description: 'This is the passage that carries air toward the lungs.',
          answer: 'TRACHEA',
          markerX: 0.50,
          markerY: 0.29,
        ),
        ScienceQuestion(
          letter: 'B',
          description: 'These organs take oxygen into the body.',
          answer: 'LUNGS',
          markerX: 0.50,
          markerY: 0.54,
        ),
        ScienceQuestion(
          letter: 'C',
          description: 'This is where air normally enters the respiratory system.',
          answer: 'NOSE',
          markerX: 0.50,
          markerY: 0.13,
        ),
        ScienceQuestion(
          letter: 'D',
          description: 'This muscle helps the lungs expand during breathing.',
          answer: 'DIAPHRAGM',
          markerX: 0.50,
          markerY: 0.79,
        ),
        // NEW (5th question) - adjust the marker to match your image.
        ScienceQuestion(
          letter: 'E',
          description: 'These tubes split from the trachea and lead into each lung.',
          answer: 'BRONCHI',
          markerX: 0.42,
          markerY: 0.40,
        ),
      ],
    ),

    // ----------------------------------------------------------
    // GEOLOGY 1: LANDFORMS
    // ----------------------------------------------------------

    ScienceChallenge(
      category: 'GEOLOGY',
      title: 'LAND FORMS',
      image: 'assets/images/science_game/geology_landforms.png',
      questions: [
        ScienceQuestion(
          letter: 'A',
          description: 'A high natural elevation with a peak.',
          answer: 'MOUNTAIN',
          markerX: 0.23,
          markerY: 0.25,
        ),
        ScienceQuestion(
          letter: 'B',
          description: 'A low area of land between hills or mountains.',
          answer: 'VALLEY',
          markerX: 0.51,
          markerY: 0.58,
        ),
        ScienceQuestion(
          letter: 'C',
          description: 'A raised area of land with a mostly flat top.',
          answer: 'PLATEAU',
          markerX: 0.77,
          markerY: 0.37,
        ),
        ScienceQuestion(
          letter: 'D',
          description: 'A large area of mostly flat land.',
          answer: 'PLAIN',
          markerX: 0.49,
          markerY: 0.84,
        ),
        // NEW (5th question) - adjust the marker to match your image.
        ScienceQuestion(
          letter: 'E',
          description: 'A rounded area of land that is lower than a mountain.',
          answer: 'HILL',
          markerX: 0.08,
          markerY: 0.62,
        ),
      ],
    ),

    // ----------------------------------------------------------
    // GEOLOGY 2: OCEAN FLOOR FEATURES
    // ----------------------------------------------------------

    ScienceChallenge(
      category: 'GEOLOGY',
      title: 'OCEAN FLOOR',
      image: 'assets/images/science_game/geology_ocean_floor.png',
      questions: [
        ScienceQuestion(
          letter: 'A',
          description: 'The shallow, gently sloping area near a continent.',
          answer: 'CONTINENTAL SHELF',
          markerX: 0.18,
          markerY: 0.43,
        ),
        ScienceQuestion(
          letter: 'B',
          description: 'The steep area connecting the shelf to the deep ocean.',
          answer: 'CONTINENTAL SLOPE',
          markerX: 0.38,
          markerY: 0.60,
        ),
        ScienceQuestion(
          letter: 'C',
          description: 'A very deep, narrow depression in the ocean floor.',
          answer: 'OCEAN TRENCH',
          markerX: 0.83,
          markerY: 0.82,
        ),
        ScienceQuestion(
          letter: 'D',
          description: 'A broad, nearly flat region of the deep ocean floor.',
          answer: 'ABYSSAL PLAIN',
          markerX: 0.63,
          markerY: 0.78,
        ),
        // NEW (5th question) - adjust the marker to match your image.
        ScienceQuestion(
          letter: 'E',
          description: 'An underwater mountain that rises from the ocean floor.',
          answer: 'SEAMOUNT',
          markerX: 0.72,
          markerY: 0.66,
        ),
      ],
    ),
  ];

  late ScienceChallenge selectedChallenge;

  // The questions used in the current round (3, 4 or 5 depending on
  // the difficulty).
  late List<ScienceQuestion> activeQuestions;

  // ============================================================
  // ANSWER DATA
  // ============================================================

  late List<String> shuffledChoices;

  // Stores the answer assigned to each question letter.
  Map<String, String?> playerAnswers = {};

  int moves = 0;
  int gameSeconds = 0;

  int score = 0;
  int xp = 0;
  int streakCount = 0;

  bool completed = false;
  bool gameEnded = false;
  bool isPaused = false;
  bool showOptions = false;
  bool isChecking = false;

  String feedbackMessage = '';

  Timer? timer;

  late ConfettiController confetti;

  final GameAudio audio = GameAudio(
    musicAsset: 'sounds/The_Measured_Proof.mp3',
  );

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    confetti = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    );

    _initAudio();
    startNewGame();
  }

  Future<void> _initAudio() async {
    await audio.init();

    if (!mounted) return;

    await audio.startMusic();
  }

  // ============================================================
  // GAME FLOW
  // ============================================================

  void startNewGame() {
    timer?.cancel();
    confetti.stop();
    _shakeController.reset();

    final random = Random();

    // Randomly select one of the four challenges.
    selectedChallenge =
        challenges[random.nextInt(challenges.length)];

    // Use only as many questions as the difficulty allows.
    activeQuestions =
        selectedChallenge.questions.take(questionCount).toList();

    // Shuffle the choices.
    shuffledChoices =
        activeQuestions.map((question) => question.answer).toList();

    shuffledChoices.shuffle(random);

    // Prepare empty answer slots.
    playerAnswers = {
      for (final question in activeQuestions) question.letter: null,
    };

    moves = 0;
    gameSeconds = totalGameDuration;

    score = 0;
    xp = 0;

    completed = false;
    gameEnded = false;
    isPaused = false;
    showOptions = false;
    isChecking = false;

    feedbackMessage = '';

    if (hasGameTimer) {
      startGameTimer();
    }
  }

  void restartGame() {
    timer?.cancel();

    setState(startNewGame);

    audio.stopEffects();
    audio.startMusic();
  }

  void pauseGame() {
    if (completed || gameEnded || isPaused) return;

    timer?.cancel();
    audio.pauseAll();

    setState(() {
      isPaused = true;
      showOptions = false;
    });
  }

  Future<void> resumeGame() async {
    if (!isPaused || completed || gameEnded) return;

    setState(() {
      isPaused = false;
      showOptions = false;
    });

    await audio.resume();

    if (!mounted) return;

    if (hasGameTimer) {
      startGameTimer();
    }
  }

  // ============================================================
  // TIMER
  // ============================================================

  void startGameTimer() {
    timer?.cancel();

    if (!hasGameTimer) return;

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        if (isPaused) return;

        setState(() {
          gameSeconds--;
        });

        if (gameSeconds <= 0) {
          t.cancel();

          _shakeController.forward(from: 0);

          audio.playWrong();

          endGame(false);
        }
      },
    );
  }

  // ============================================================
  // DRAG AND DROP
  // ============================================================

  void placeAnswer(String letter, String answer) {
    if (completed || gameEnded || isPaused) return;

    final previousLetter = playerAnswers.entries
        .where((entry) => entry.value == answer)
        .map((entry) => entry.key)
        .firstOrNull;

    setState(() {
      // Remove the answer from its previous slot if it was already used.
      if (previousLetter != null) {
        playerAnswers[previousLetter] = null;
      }

      // Place it in the selected answer slot.
      playerAnswers[letter] = answer;

      moves++;

      feedbackMessage = '';

      audio.playSfx('pop.mp3');
    });
  }

  void removeAnswer(String letter) {
    if (completed || gameEnded || isPaused) return;

    if (playerAnswers[letter] == null) return;

    setState(() {
      playerAnswers[letter] = null;
      feedbackMessage = '';
    });

    audio.playSfx('click.mp3');
  }

  bool get allAnswersFilled {
    return playerAnswers.values.every(
      (answer) => answer != null,
    );
  }

  int get correctAnswers {
    int correct = 0;

    for (final question in activeQuestions) {
      if (playerAnswers[question.letter] == question.answer) {
        correct++;
      }
    }

    return correct;
  }

  // ============================================================
  // SUBMIT ANSWERS
  // ============================================================

  void submitAnswers() {
    if (completed || gameEnded || isChecking) return;

    if (!allAnswersFilled) {
      setState(() {
        feedbackMessage = 'Fill in all the answer spaces first!';
      });

      audio.playWrong();
      return;
    }

    setState(() {
      isChecking = true;
    });

    final correct = correctAnswers;
    final total = activeQuestions.length;

    if (correct == total) {
      audio.playComplete();
      endGame(true);
    } else {
      setState(() {
        feedbackMessage =
            '$correct out of $total correct. Check your answers and try again!';
        isChecking = false;
      });

      _shakeController.forward(from: 0);

      audio.playWrong();
    }
  }

  // ============================================================
  // SCORING
  // ============================================================

  void calculateResults() {
    final int timeUsed =
        hasGameTimer ? totalGameDuration - gameSeconds : 0;

    int calculatedScore = 1000;

    calculatedScore -= moves * 10;

    if (hasGameTimer) {
      calculatedScore -= timeUsed * 5;
    }

    if (calculatedScore < 0) {
      calculatedScore = 0;
    }

    score = calculatedScore;

    xp = 20;

    // Bonus for using few moves (about 2 moves per question).
    if (moves <= questionCount * 2) xp += 10;

    // Bonus for finishing in half the time or less.
    if (hasGameTimer && timeUsed <= totalGameDuration ~/ 2) {
      xp += 10;
    }
  }

  String getGrade() {
    if (score >= 900) return 'S';
    if (score >= 750) return 'A';
    if (score >= 600) return 'B';
    if (score >= 450) return 'C';

    return 'D';
  }

  // ============================================================
  // END GAME
  // ============================================================

  void endGame(bool win) {
    if (gameEnded) return;

    gameEnded = true;
    timer?.cancel();

    audio.stopMusic();

    if (win) {
      calculateResults();

      streakCount++;

      confetti.play();

      audio.playComplete();
    } else {
      xp = 0;
      score = 0;
      streakCount = 0;
    }

    setState(() {
      completed = true;
    });

    saveScore(win);
  }

  // ============================================================
  // FIRESTORE SCORE SAVING
  // ============================================================

  Future<void> saveScore(bool win) async {
    try {
      final identityFields = await ScoreIdentity.fields();

      await FirebaseFirestore.instance
          .collection('scores')
          .add({
        ...identityFields,

        // Update this level number if Body Explorer
        // is assigned to a different level in your game.
        'level': 9,
        'levelName': 'Body Explorer',

        'difficulty': widget.difficulty.label,

        'category': selectedChallenge.category,
        'challenge': selectedChallenge.title,
        'image': selectedChallenge.image,

        'moves': moves,
        'correctAnswers': win
            ? activeQuestions.length
            : correctAnswers,
        'totalQuestions': activeQuestions.length,

        'score': score,
        'xp': xp,
        'grade': win ? getGrade() : 'F',
        'completed': win,

        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('Body Explorer score saved successfully.');
    } catch (e) {
      debugPrint('Error saving Body Explorer score: $e');
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void goToMainMenu() {
    Navigator.pop(context);
  }

  void goToPreviousLevel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SciencePuzzle(
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  // ============================================================
  // BUTTON DESIGN
  // ============================================================

  Widget _buildChunkyButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool iconAfterText = false,
  }) {
    final iconWidget = Icon(
      icon,
      color: Colors.white,
      size: 20,
    );

    final textWidget = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );

    return GestureDetector(
      onTap: onPressed,
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
              ? [
                  textWidget,
                  const SizedBox(width: 8),
                  iconWidget,
                ]
              : [
                  iconWidget,
                  const SizedBox(width: 8),
                  textWidget,
                ],
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  Widget _buildCustomAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'Body Explorer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            IconButton(
              onPressed: pauseGame,
              icon: const Icon(
                Icons.pause_circle_filled,
                color: Colors.amber,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HUD CARD
  // ============================================================

  Widget _buildHudCard({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8,
          sigmaY: 8,
        ),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHOICE SHEET
  // ============================================================

  Widget _buildChoiceSheet() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.drag_indicator,
                color: Colors.amber,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                'CHOICE SHEET',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          const Text(
            'Drag each answer into the correct blank space.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: shuffledChoices.map((answer) {
              final isUsed = playerAnswers.values.contains(answer);

              return Draggable<String>(
                data: answer,

                maxSimultaneousDrags: isUsed ? 0 : 1,

                feedback: Material(
                  color: Colors.transparent,
                  child: _buildAnswerChip(
                    answer,
                    isDragging: true,
                  ),
                ),

                childWhenDragging: Opacity(
                  opacity: 0.25,
                  child: _buildAnswerChip(answer),
                ),

                child: _buildAnswerChip(
                  answer,
                  isUsed: isUsed,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerChip(
    String answer, {
    bool isDragging = false,
    bool isUsed = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(
        minWidth: 65,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: isUsed
            ? Colors.white24
            : const Color(0xFF9B8AD6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDragging ? Colors.amber : Colors.white30,
          width: isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Text(
        answer,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: answer.length > 12 ? 10 : 12,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ============================================================
  // ILLUSTRATION
  // ============================================================

  Widget _buildIllustrationPanel() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Text(
            'ILLUSTRATION',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        selectedChallenge.image,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.white,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(12),
                            child: const Text(
                              'Illustration not found.\nCheck the image asset path.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // LETTER MARKERS (only for the active questions)
                    ...activeQuestions.map((question) {
                      return Positioned(
                        left: (constraints.maxWidth *
                                question.markerX) -
                            15,
                        top: (constraints.maxHeight *
                                question.markerY) -
                            15,
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            question.letter,
                            style: const TextStyle(
                              color: Color(0xFF4A0E4E),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Identify the marked areas.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANSWER SHEET
  // ============================================================

  Widget _buildAnswerSheet() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Text(
            'ANSWER SHEET',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: activeQuestions.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final question = activeQuestions[index];

                return _buildQuestionDropZone(question);
              },
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '${playerAnswers.values.where((answer) => answer != null).length}/${activeQuestions.length} ANSWERED',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionDropZone(ScienceQuestion question) {
    final currentAnswer = playerAnswers[question.letter];

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        return !completed && !gameEnded && !isPaused;
      },

      onAcceptWithDetails: (details) {
        placeAnswer(
          question.letter,
          details.data,
        );
      },

      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHovering
                ? Colors.amber.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? Colors.amber
                  : Colors.white24,
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      question.letter,
                      style: const TextStyle(
                        color: Color(0xFF4A0E4E),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      question.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              GestureDetector(
                onTap: currentAnswer == null
                    ? null
                    : () => removeAnswer(question.letter),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 34,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: currentAnswer == null
                        ? Colors.black.withValues(alpha: 0.15)
                        : const Color(0xFF2EC4B6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentAnswer == null
                          ? Colors.white38
                          : Colors.white70,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          currentAnswer ?? 'DROP ANSWER HERE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: currentAnswer == null
                                ? Colors.white54
                                : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: currentAnswer != null &&
                                    currentAnswer.length > 12
                                ? 9
                                : 10,
                          ),
                        ),
                      ),

                      if (currentAnswer != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.close,
                          size: 13,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // GAMEPLAY LAYOUT
  // ============================================================

  Widget _buildGameplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // HUD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHudCard(
                icon: Icons.timer_outlined,
                title: 'TIME',
                value: hasGameTimer ? '${gameSeconds}s' : '∞',
                valueColor: Colors.cyanAccent,
              ),

              _buildHudCard(
                icon: Icons.touch_app_rounded,
                title: 'MOVES',
                value: '$moves',
                valueColor: Colors.purpleAccent,
              ),

              _buildHudCard(
                icon: Icons.local_fire_department,
                title: 'STREAK',
                value: '$streakCount',
                valueColor: Colors.orangeAccent,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // CATEGORY AND CHALLENGE
          Text(
            '${selectedChallenge.category} • ${selectedChallenge.title}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 8),

          // CHOICE SHEET ON TOP
          _buildChoiceSheet(),

          const SizedBox(height: 10),

          // ILLUSTRATION LEFT + ANSWER SHEET RIGHT
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildIllustrationPanel(),
                ),

                const SizedBox(width: 9),

                Expanded(
                  flex: 6,
                  child: _buildAnswerSheet(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // FEEDBACK
          if (feedbackMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                feedbackMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),

          // SUBMIT BUTTON
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: _buildChunkyButton(
                label: 'SUBMIT ANSWERS',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF2EC4B6),
                onPressed: submitAnswers,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULT SCREEN
  // ============================================================

  Widget buildResultScreen() {
    final bool passed = xp > 0;

    final int timeUsed =
        hasGameTimer ? totalGameDuration - gameSeconds : 0;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    passed
                        ? '🎉 LEVEL COMPLETE!'
                        : '⏰ TIME IS UP!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: passed
                          ? Colors.amber
                          : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    passed
                        ? 'Excellent! You identified everything correctly.'
                        : 'Time ran out! Try again and complete the challenge.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (passed) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text(
                        'GRADE: ${getGrade()}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBadge('🏆 Score', '$score'),
                      _buildStatBadge(
                        '⭐ XP',
                        passed ? '+$xp' : '0',
                      ),
                      _buildStatBadge('🧩 Moves', '$moves'),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Challenge: ${selectedChallenge.title}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (hasGameTimer) ...[
                    const SizedBox(height: 5),
                    Text(
                      '⏱ Time Used: ${timeUsed}s',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  _buildChunkyButton(
                    label: 'Try Again',
                    icon: Icons.refresh_rounded,
                    color: const Color(0xFF2EC4B6),
                    onPressed: restartGame,
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _buildChunkyButton(
                          label: 'Previous',
                          icon: Icons.arrow_back_rounded,
                          color: const Color(0xFF9B8AD6),
                          onPressed: goToPreviousLevel,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _buildChunkyButton(
                          label: 'Main Menu',
                          icon: Icons.home_rounded,
                          color: Colors.white24,
                          onPressed: goToMainMenu,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A0E4E),
              Color(0xFF811252),
              Color(0xFF2E0854),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildCustomAppBar(),

                Expanded(
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final t = _shakeAnimation.value;

                      final dx =
                          sin(t * pi * 6) * 10 * (1 - t);

                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: completed
                        ? buildResultScreen()
                        : _buildGameplay(),
                  ),
                ),
              ],
            ),

            // PAUSE AND OPTIONS
            if (isPaused)
              Positioned.fill(
                child: showOptions
                    ? GameOptionsMenu(
                        audio: audio,
                        onBack: () {
                          setState(() {
                            showOptions = false;
                          });
                        },
                      )
                    : PauseMenu(
                        onResume: resumeGame,
                        onRestart: restartGame,
                        onOptions: () {
                          setState(() {
                            showOptions = true;
                          });
                        },
                        onMainMenu: goToMainMenu,
                      ),
              ),

            // CONFETTI
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confetti,
                blastDirectionality:
                    BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.amber,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    timer?.cancel();
    confetti.dispose();
    audio.dispose();
    _shakeController.dispose();

    super.dispose();
  }
}