import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class MathGame extends StatefulWidget {
  const MathGame({super.key});

  @override
  State<MathGame> createState() => _MathGameState();
}

class _MathGameState extends State<MathGame> {
  final TextEditingController answerController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  late ConfettiController confettiController;
  Timer? questionTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();

  int num1 = 0;
  int num2 = 0;
  int correctAnswer = 0;

  String operator = "+";
  String question = "";

  int correctCount = 0;
  int wrongCount = 0;

  int questionCount = 0;
  static const int maxQuestions = 10;

  int questionTime = 10;

  bool gameOver = false;

  // PAUSE SYSTEM
  bool isPaused = false;

  int xp = 0;
  int streak = 0;
  int bestStreak = 0;

  bool showFeedback = false;
  String feedbackText = "";
  bool lastAnswerCorrect = false;

  bool showError = false;
  double shakeOffset = 0;

  double screenShake = 0;

  bool showXpPopup = false;
  int xpGained = 0;

  // Used to safely cancel delayed question transitions.
  int _gameSession = 0;

  @override
  void initState() {
    super.initState();

    confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    generateQuestion();
  }

  // ============================================================
  // SOUND
  // ============================================================

  void _playSound(String fileName) {
    _audioPlayer.stop();
    _audioPlayer.play(
      AssetSource('sounds/$fileName'),
    );

    debugPrint('Playing: $fileName');
  }

  void playCorrectSound() => _playSound('correct.mp3');

  void playWrongSound() => _playSound('wrong.mp3');

  void playCompleteSound() => _playSound('level up.mp3');

  // ============================================================
  // PAUSE SYSTEM
  // ============================================================

  void pauseGame() {
    if (gameOver || isPaused) return;

    questionTimer?.cancel();

    setState(() {
      isPaused = true;
    });

    FocusScope.of(context).unfocus();
    _audioPlayer.pause();
  }

  void resumeGame() {
    if (!isPaused || gameOver) return;

    setState(() {
      isPaused = false;
    });

    _audioPlayer.resume();
    startQuestionTimer(resetTime: false);
  }

  // ============================================================
  // QUESTION TIMER
  // ============================================================

  void startQuestionTimer({bool resetTime = true}) {
    questionTimer?.cancel();

    if (resetTime) {
      questionTime = 10;
    }

    questionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (isPaused) return;

        if (questionTime <= 0) {
          timer.cancel();
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
    questionTimer?.cancel();

    final int currentSession = _gameSession;

    feedbackText = "Time's up! ❌ Correct: $correctAnswer";

    wrongCount++;
    streak = 0;

    setState(() {
      showFeedback = true;
      lastAnswerCorrect = false;
    });

    answerController.clear();

    Future.delayed(
      const Duration(milliseconds: 700),
      () {
        if (!mounted) return;
        if (isPaused) return;
        if (currentSession != _gameSession) return;

        setState(() {
          showFeedback = false;
          questionCount++;
        });

        if (questionCount >= maxQuestions) {
          setState(() {
            gameOver = true;
          });

          playCompleteSound();
          confettiController.play();
          saveScore();

          return;
        }

        generateQuestion();
      },
    );
  }

  // ============================================================
  // ERROR ANIMATION
  // ============================================================

  void triggerError() {
    if (isPaused) return;

    setState(() {
      showError = true;
      shakeOffset = 10;
    });

    Future.delayed(
      const Duration(milliseconds: 100),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          shakeOffset = -10;
        });
      },
    );

    Future.delayed(
      const Duration(milliseconds: 200),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          shakeOffset = 10;
        });
      },
    );

    Future.delayed(
      const Duration(milliseconds: 300),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          shakeOffset = 0;
        });
      },
    );

    Future.delayed(
      const Duration(seconds: 2),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          showError = false;
        });
      },
    );
  }

  // ============================================================
  // SCREEN SHAKE
  // ============================================================

  void triggerScreenShake() {
    if (isPaused) return;

    setState(() {
      screenShake = 10;
    });

    Future.delayed(
      const Duration(milliseconds: 100),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          screenShake = -10;
        });
      },
    );

    Future.delayed(
      const Duration(milliseconds: 200),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          screenShake = 10;
        });
      },
    );

    Future.delayed(
      const Duration(milliseconds: 300),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          screenShake = 0;
        });
      },
    );
  }

  // ============================================================
  // XP POPUP
  // ============================================================

  void showXpGain(int amount) {
    if (isPaused) return;

    setState(() {
      showXpPopup = true;
      xpGained = amount;
    });

    Future.delayed(
      const Duration(milliseconds: 600),
      () {
        if (!mounted || isPaused) return;

        setState(() {
          showXpPopup = false;
        });
      },
    );
  }

  // ============================================================
  // GENERATE QUESTION
  // ============================================================

  void generateQuestion() {
    if (gameOver || isPaused) return;

    final random = Random();

    num1 = random.nextInt(20) + 1;
    num2 = random.nextInt(20) + 1;

    if (random.nextBool()) {
      operator = "+";
      correctAnswer = num1 + num2;
    } else {
      operator = "-";

      if (num2 > num1) {
        int temp = num1;
        num1 = num2;
        num2 = temp;
      }

      correctAnswer = num1 - num2;
    }

    setState(() {
      question = "$num1 $operator $num2 = ?";
    });

    startQuestionTimer();
  }

  // ============================================================
  // CHECK ANSWER
  // ============================================================

  void checkAnswer({bool isTimeout = false}) {
    if (isPaused || gameOver) return;

    if (answerController.text.trim().isEmpty) {
      triggerError();
      return;
    }

    questionTimer?.cancel();

    int userAnswer = int.tryParse(answerController.text) ?? -999;

    bool isCorrect = userAnswer == correctAnswer;

    if (isTimeout) {
      isCorrect = false;
      feedbackText = "Time's up! ❌ Correct: $correctAnswer";
    } else if (isCorrect) {
      feedbackText = "CORRECT! 🎉";
    } else {
      feedbackText = "WRONG! ❌ Correct: $correctAnswer";
    }

    if (isCorrect) {
      correctCount++;
      streak++;

      int xpEarned = 10;

      if (streak % 3 == 0) {
        xpEarned += 5;
      }

      xp += xpEarned;

      if (streak > bestStreak) {
        bestStreak = streak;
      }

      showXpGain(xpEarned);
      playCorrectSound();
    } else {
      wrongCount++;
      streak = 0;

      triggerScreenShake();
      playWrongSound();
    }

    setState(() {
      showFeedback = true;
      lastAnswerCorrect = isCorrect;
    });

    answerController.clear();

    final int currentSession = _gameSession;

    Future.delayed(
      const Duration(milliseconds: 700),
      () {
        if (!mounted) return;

        if (isPaused) return;

        if (currentSession != _gameSession) return;

        setState(() {
          showFeedback = false;
          questionCount++;
        });

        if (questionCount >= maxQuestions) {
          setState(() {
            gameOver = true;
          });

          playCompleteSound();
          confettiController.play();
          saveScore();

          return;
        }

        generateQuestion();
      },
    );
  }

  // ============================================================
  // SCORE / GRADE
  // ============================================================

  double get accuracy {
    if (questionCount == 0) return 0;

    return (correctCount / questionCount) * 100;
  }

  String getGrade() {
    double percent = accuracy;

    if (percent >= 90) return "S";
    if (percent >= 80) return "A";
    if (percent >= 70) return "B";
    if (percent >= 60) return "C";

    return "D";
  }

  // ============================================================
  // FIRESTORE
  // ============================================================

  void saveScore() async {
    await FirebaseFirestore.instance.collection('scores').add({
      'correct': correctCount,
      'wrong': wrongCount,
      'accuracy': accuracy,
      'xp': xp,
      'streak': bestStreak,
      'grade': getGrade(),
      'timestamp': DateTime.now(),
    });
  }

  // ============================================================
  // RESTART GAME
  // ============================================================

  void restartGame() {
    questionTimer?.cancel();
    _gameSession++;

    setState(() {
      num1 = 0;
      num2 = 0;
      correctAnswer = 0;

      operator = "+";
      question = "";

      correctCount = 0;
      wrongCount = 0;

      questionCount = 0;

      questionTime = 10;

      gameOver = false;
      isPaused = false;

      xp = 0;
      streak = 0;
      bestStreak = 0;

      showFeedback = false;
      feedbackText = "";
      lastAnswerCorrect = false;

      showError = false;
      shakeOffset = 0;

      screenShake = 0;

      showXpPopup = false;
      xpGained = 0;

      answerController.clear();
    });

    generateQuestion();
  }

  @override
  void dispose() {
    _gameSession++;

    confettiController.dispose();
    questionTimer?.cancel();
    _audioPlayer.dispose();
    focusNode.dispose();
    answerController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A0E4E),
              Color(0xFF811252),
              Color(0xFF2E0854),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ====================================================
              // MAIN GAME BODY
              // ====================================================
              Transform.translate(
                offset: Offset(screenShake, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // CUSTOM TOP APP BAR
                      _buildTopHeader(context),

                      Expanded(
                        child: gameOver
                            ? _buildLevelCompleteScreen()
                            : _buildGameplayScreen(),
                      ),
                    ],
                  ),
                ),
              ),

              // ====================================================
              // XP POPUP
              // ====================================================
              if (showXpPopup)
                Positioned(
                  top: 180,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: showXpPopup ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          "+$xpGained XP",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4A0E4E),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ====================================================
              // CONFETTI
              // ====================================================
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFF38EF7D),
                    Color(0xFFFF8008),
                    Colors.pink,
                    Colors.purple,
                  ],
                ),
              ),

              // ====================================================
              // PAUSE MENU OVERLAY
              // ====================================================
              if (isPaused)
                Positioned.fill(
                  child: PauseMenu(
                    onResume: resumeGame,
                    onRestart: restartGame,
                    onOptions: () {},
                    onMainMenu: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // HEADER BAR WITH BACK & PAUSE BUTTONS
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // BACK BUTTON
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),

          // TITLE BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 1.5,
              ),
            ),
            child: const Text(
              "LEVEL 1: MATH",
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // PAUSE BUTTON
          if (!gameOver && !isPaused)
            InkWell(
              onTap: pauseGame,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            )
          else
            const SizedBox(width: 42),
        ],
      ),
    );
  }

  // ============================================================
  // GAMEPLAY SCREEN
  // ============================================================
  Widget _buildGameplayScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // STATS HUD ROW
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHudItem("⭐ XP", "$xp", Colors.amber),
              _buildHudItem("🔥 Streak", "$streak", Colors.orangeAccent),
              _buildHudItem("🏆 Best", "$bestStreak", Colors.cyanAccent),
            ],
          ),
        ),

        // QUESTION COUNTER & TIMER CARD
        Column(
          children: [
            Text(
              "QUESTION ${questionCount + 1} OF $maxQuestions",
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            // TIMER BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: questionTime <= 3
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: questionTime <= 3 ? Colors.redAccent : Colors.white30,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: questionTime <= 3
                        ? Colors.redAccent
                        : const Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "$questionTime SEC",
                    style: TextStyle(
                      color: questionTime <= 3
                          ? Colors.redAccent
                          : const Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // MAIN QUESTION DISPLAY CARD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              question,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    offset: Offset(2, 3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),

        // INPUT FIELD & SUBMIT BUTTON
        Column(
          children: [
            Transform.translate(
              offset: Offset(shakeOffset, 0),
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: showError
                        ? Colors.redAccent
                        : const Color(0xFFFFD700),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: answerController,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  enabled: !isPaused,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2E0854),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    hintText: "?",
                    hintStyle: TextStyle(
                      color: Colors.black26,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3D SUBMIT BUTTON
            _3DButton(
              text: "SUBMIT",
              color: const Color(0xFF38EF7D),
              shadowColor: const Color(0xFF0C6B63),
              textColor: const Color(0xFF003816),
              onPressed: isPaused ? () {} : checkAnswer,
            ),
          ],
        ),

        // FEEDBACK MESSAGE
        AnimatedOpacity(
          opacity: showFeedback ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: lastAnswerCorrect
                  ? Colors.green.withOpacity(0.3)
                  : Colors.redAccent.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: lastAnswerCorrect ? Colors.green : Colors.redAccent,
              ),
            ),
            child: Text(
              feedbackText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: lastAnswerCorrect ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LEVEL COMPLETE SCREEN
  // ============================================================
  Widget _buildLevelCompleteScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "🎉 LEVEL COMPLETE!",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD700),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 25),

        // GRADE BADGE
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFFFD700), width: 4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 15,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              getGrade(),
              style: const TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w900,
                color: Color(0xFF811252),
              ),
            ),
          ),
        ),

        const SizedBox(height: 25),

        // STATS CARD
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              _buildStatRow("XP Earned:", "+$xp"),
              const Divider(color: Colors.white12),
              _buildStatRow("Best Streak:", "$bestStreak 🔥"),
              const Divider(color: Colors.white12),
              _buildStatRow("Correct Answers:", "$correctCount / $maxQuestions"),
              const Divider(color: Colors.white12),
              _buildStatRow("Accuracy:", "${accuracy.toStringAsFixed(0)}%"),
            ],
          ),
        ),

        const SizedBox(height: 35),

        // RESTART BUTTON
        _3DButton(
          text: "PLAY AGAIN",
          color: const Color(0xFFFF8008),
          shadowColor: const Color(0xFF993D00),
          textColor: Colors.white,
          onPressed: restartGame,
        ),
      ],
    );
  }

  Widget _buildHudItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// REUSABLE CHUNKY 3D GAME BUTTON
class _3DButton extends StatefulWidget {
  final String text;
  final Color color;
  final Color shadowColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _3DButton({
    required this.text,
    required this.color,
    required this.shadowColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  State<_3DButton> createState() => _3DButtonState();
}

class _3DButtonState extends State<_3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 200,
        height: 54,
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, _isPressed ? 1 : 5),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 6),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}