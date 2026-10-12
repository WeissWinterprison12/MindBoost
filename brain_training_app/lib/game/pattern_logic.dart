import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class PatternLogic extends StatefulWidget {
  const PatternLogic({super.key});

  @override
  State<PatternLogic> createState() => _PatternLogicState();
}

class _PatternLogicState extends State<PatternLogic>
    with TickerProviderStateMixin {
  // ============================================================
  // SETTINGS
  // ============================================================

  static const int questionDuration = 10;

  final AudioPlayer _audioPlayer = AudioPlayer();

  late ConfettiController confettiController;

  late AnimationController _shakeController;

  Timer? questionTimer;

  // ============================================================
  // GAME STATE
  // ============================================================

  int questionIndex = 0;
  int correctCount = 0;
  int wrongCount = 0;

  int questionTime = questionDuration;

  int xp = 0;

  int streak = 0;
  int bestStreak = 0;

  bool gameOver = false;
  bool answered = false;
  bool isPaused = false;

  String? selectedAnswer;

  String feedbackText = '';
  bool lastAnswerCorrect = false;

  // ============================================================
  // QUESTIONS
  // ============================================================

  final List<Map<String, dynamic>> questions = [
    {
      'pattern': '2 → 4 → 6 → 8 → ?',
      'answers': ['9', '10', '11', '12'],
      'correct': '10',
    },
    {
      'pattern': '5 → 10 → 15 → 20 → ?',
      'answers': ['25', '30', '22', '24'],
      'correct': '25',
    },
    {
      'pattern': '🔴 → 🔵 → 🔴 → 🔵 → ?',
      'answers': ['🟢', '🔴', '🟡', '🔵'],
      'correct': '🔴',
    },
    {
      'pattern': '3 → 6 → 9 → 12 → ?',
      'answers': ['14', '15', '16', '18'],
      'correct': '15',
    },
    {
      'pattern': '10 → 20 → 30 → 40 → ?',
      'answers': ['45', '50', '55', '60'],
      'correct': '50',
    },
    {
      'pattern': '1 → 4 → 9 → 16 → ?',
      'answers': ['20', '24', '25', '30'],
      'correct': '25',
    },
    {
      'pattern': '100 → 90 → 80 → 70 → ?',
      'answers': ['50', '55', '60', '65'],
      'correct': '60',
    },
    {
      'pattern': '🔺 → 🔵 → 🟢 → 🔺 → 🔵 → ?',
      'answers': ['🔴', '🟢', '🟡', '🔵'],
      'correct': '🟢',
    },
    {
      'pattern': '2 → 6 → 12 → 20 → ?',
      'answers': ['24', '28', '30', '32'],
      'correct': '30',
    },
    {
      'pattern': '50 → 45 → 40 → 35 → ?',
      'answers': ['25', '30', '32', '40'],
      'correct': '30',
    },
  ];

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );


    startQuestionTimer();
  }

  // ============================================================
  // SOUND
  // ============================================================

  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void playCorrectSound() => _playSound('correct.mp3');

  void playWrongSound() => _playSound('wrong.mp3');

  void playCompleteSound() => _playSound('level up.mp3');

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  void pauseGame() {
    if (gameOver || isPaused) return;

    questionTimer?.cancel();

    _audioPlayer.pause();

    setState(() {
      isPaused = true;
    });
  }

  void resumeGame() {
    if (!isPaused || gameOver) return;

    setState(() {
      isPaused = false;
    });

    _audioPlayer.resume();

    if (answered) {
      // Paused during the feedback moment:
      // continue to the next question.
      Future.delayed(
        const Duration(milliseconds: 500),
        () {
          if (!mounted || isPaused) return;
          nextQuestion();
        },
      );
    } else {
      // Keep the remaining time.
      startQuestionTimer(resetTime: false);
    }
  }

  // ============================================================
  // TIMER
  // ============================================================

  void startQuestionTimer({
    bool resetTime = true,
  }) {
    questionTimer?.cancel();

    if (resetTime) {
      questionTime = questionDuration;
    }

    setState(() {
      answered = false;
    });

    questionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (isPaused) return;

        if (questionTime <= 1) {
          timer.cancel();

          setState(() {
            questionTime = 0;
          });

          handleTimeout();
        } else {
          setState(() {
            questionTime--;
          });
        }
      },
    );
  }

  // ============================================================
  // TIMEOUT
  // ============================================================

  void handleTimeout() {
    if (answered || gameOver || isPaused) return;

    questionTimer?.cancel();

    final correctAnswer = questions[questionIndex]['correct'];

    setState(() {
      answered = true;
      selectedAnswer = null;

      wrongCount++;
      streak = 0;

      feedbackText = "Time's up! ❌ Correct: $correctAnswer";
      lastAnswerCorrect = false;
    });

    _shakeController.forward(from: 0.0);

    playWrongSound();

    _scheduleNextQuestion();
  }

  // ============================================================
  // ANSWER
  // ============================================================

  void checkAnswer(String answer) {
    if (answered || gameOver || isPaused) return;

    questionTimer?.cancel();

    final correctAnswer = questions[questionIndex]['correct'];

    final isCorrect = answer == correctAnswer;

    setState(() {
      answered = true;
      selectedAnswer = answer;

      if (isCorrect) {
        correctCount++;
        streak++;

        int xpEarned = 10;

        // Streak bonus every 3 correct answers.
        if (streak % 3 == 0) {
          xpEarned += 5;
        }

        xp += xpEarned;

        if (streak > bestStreak) {
          bestStreak = streak;
        }

        feedbackText = 'Correct! ✔';
        lastAnswerCorrect = true;
      } else {
        wrongCount++;
        streak = 0;

        feedbackText = 'Wrong! ❌ Correct: $correctAnswer';
        lastAnswerCorrect = false;
      }
    });

    if (isCorrect) {
      playCorrectSound();
    } else {
      _shakeController.forward(from: 0.0);
      playWrongSound();
    }

    _scheduleNextQuestion();
  }

  void _scheduleNextQuestion() {
    Future.delayed(
      const Duration(milliseconds: 900),
      () {
        if (!mounted) return;

        // Do not advance while paused.
        if (isPaused) return;

        nextQuestion();
      },
    );
  }

  // ============================================================
  // NEXT QUESTION
  // ============================================================

  void nextQuestion() {
    if (!mounted || isPaused) return;

    if (questionIndex >= questions.length - 1) {
      finishGame();
      return;
    }

    setState(() {
      questionIndex++;

      feedbackText = '';
      selectedAnswer = null;
      answered = false;
    });

    startQuestionTimer();
  }

  // ============================================================
  // FINISH GAME
  // ============================================================

  void finishGame() {
    questionTimer?.cancel();

    setState(() {
      gameOver = true;
      isPaused = false;
    });

    playCompleteSound();

    confettiController.play();

    saveScore();
  }

  // ============================================================
  // ACCURACY / GRADE
  // ============================================================

  double get accuracy {
    final total = correctCount + wrongCount;

    if (total == 0) return 0;

    return (correctCount / total) * 100;
  }

  String getGrade() {
    if (accuracy >= 90) return 'S';
    if (accuracy >= 80) return 'A';
    if (accuracy >= 70) return 'B';
    if (accuracy >= 60) return 'C';

    return 'D';
  }

  // ============================================================
  // SAVE SCORE
  // ============================================================

  Future<void> saveScore() async {
    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Pattern Logic',
        'correct': correctCount,
        'wrong': wrongCount,
        'accuracy': accuracy,
        'xp': xp,
        'streak': bestStreak,
        'grade': getGrade(),
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error saving Pattern Logic score: $e');
    }
  }

  // ============================================================
  // RESTART / NAVIGATION
  // ============================================================

  void restartGame() {
    questionTimer?.cancel();

    _audioPlayer.stop();

    setState(() {
      questionIndex = 0;

      correctCount = 0;
      wrongCount = 0;

      questionTime = questionDuration;

      xp = 0;

      streak = 0;
      bestStreak = 0;

      gameOver = false;
      answered = false;
      isPaused = false;

      selectedAnswer = null;

      feedbackText = '';
      lastAnswerCorrect = false;
    });

    startQuestionTimer();
  }

  void goToMainMenu() {
    Navigator.pop(context);
  }

  // ============================================================
  // CHUNKY BUTTON
  // ============================================================

  Widget _buildChunkyButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
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
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM APP BAR
  // ============================================================

  Widget _buildCustomAppBar() {
    return SafeArea(
      bottom: false,
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
                'Pattern Logic',
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
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white70, size: 14),
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
      ),
    );
  }

  // ============================================================
  // STAT BADGE
  // ============================================================

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
  // ANSWER BUTTON
  // ============================================================

  Widget _buildAnswerButton(String answer) {
    final String correctAnswer =
        questions[questionIndex]['correct'] as String;

    final bool isCorrectAnswer = answer == correctAnswer;
    final bool isSelected = selectedAnswer == answer;

    // Default look.
    List<Color> colors = const [
      Color(0xFF6A1B9A),
      Color(0xFF3949AB),
    ];

    double opacity = 1.0;

    if (answered) {
      if (isCorrectAnswer) {
        colors = const [
          Color(0xFF2E7D32),
          Color(0xFF43A047),
        ];
      } else if (isSelected) {
        colors = const [
          Color(0xFFC62828),
          Color(0xFFE53935),
        ];
      } else {
        opacity = 0.4;
      }
    }

    return GestureDetector(
      onTap: (answered || isPaused) ? null : () => checkAnswer(answer),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: answered && isCorrectAnswer
                  ? Colors.greenAccent
                  : Colors.white24,
              width: answered && isCorrectAnswer ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  answer,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GAMEPLAY CONTENT
  // ============================================================

  Widget _buildGameplay() {
    final currentQuestion = questions[questionIndex];

    final String pattern = currentQuestion['pattern'] as String;

    final List<dynamic> answers =
        currentQuestion['answers'] as List<dynamic>;

    final bool lowTime = questionTime <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // HUD
          Row(
            children: [
              Expanded(
                child: _buildHudCard(
                  icon: Icons.timer_outlined,
                  title: 'TIME',
                  value: '${questionTime}s',
                  valueColor:
                      lowTime ? Colors.redAccent : Colors.cyanAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.star_rounded,
                  title: 'XP',
                  value: '$xp',
                  valueColor: Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.local_fire_department,
                  title: 'STREAK',
                  value: '$streak',
                  valueColor: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.emoji_events_rounded,
                  title: 'BEST',
                  value: '$bestStreak',
                  valueColor: Colors.purpleAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content: scrolls only if a very small screen needs it
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
          // Title
          Text(
            'QUESTION ${questionIndex + 1}/${questions.length}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.cyanAccent,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          // Timer bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: questionTime / questionDuration,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                lowTime ? Colors.redAccent : Colors.cyanAccent,
              ),
            ),
          ),

          const SizedBox(height: 14),


                  // Pattern card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          pattern,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Answers
                  GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.0,
                    ),
                    itemCount: answers.length,
                    itemBuilder: (context, index) {
                      return _buildAnswerButton(
                        answers[index].toString(),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Feedback (fixed height so nothing jumps)
                  SizedBox(
                    height: 28,
                    child: feedbackText.isEmpty
                        ? null
                        : Text(
                            feedbackText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: lastAnswerCorrect
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Instruction
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              answered
                  ? 'Get ready for the next one...'
                  : 'Pick the answer that continues the pattern',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w500,
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

  Widget buildGameOverScreen() {
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
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  const Text(
                    '🎉 LEVEL COMPLETE!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Great job spotting the patterns!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 16),

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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBadge('⭐ XP', '+$xp'),
                      _buildStatBadge('🎯 Accuracy',
                          '${accuracy.toStringAsFixed(0)}%'),
                      _buildStatBadge('🔥 Best', '$bestStreak'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '✅ Correct: $correctCount     ❌ Wrong: $wrongCount',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildChunkyButton(
                    label: 'Try Again',
                    icon: Icons.refresh_rounded,
                    color: const Color(0xFF2EC4B6),
                    onPressed: restartGame,
                  ),

                  const SizedBox(height: 10),

                  _buildChunkyButton(
                    label: 'Main Menu',
                    icon: Icons.home_rounded,
                    color: Colors.white24,
                    onPressed: goToMainMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
                    animation: _shakeController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          sin(_shakeController.value * pi * 6) *
                              8 *
                              (1 - _shakeController.value),
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: gameOver
                        ? buildGameOverScreen()
                        : _buildGameplay(),
                  ),
                ),
              ],
            ),

            // Pause menu
            if (isPaused)
              Positioned.fill(
                child: PauseMenu(
                  onResume: resumeGame,
                  onRestart: restartGame,
                  onOptions: () {},
                  onMainMenu: goToMainMenu,
                ),
              ),

            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confettiController,
                blastDirectionality: BlastDirectionality.explosive,
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
    questionTimer?.cancel();

    confettiController.dispose();

    _audioPlayer.dispose();

    _shakeController.dispose();

    super.dispose();
  }
}