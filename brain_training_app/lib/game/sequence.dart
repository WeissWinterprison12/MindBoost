import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class SequenceRecall extends StatefulWidget {
  const SequenceRecall({super.key});

  @override
  State<SequenceRecall> createState() => _SequenceRecallState();
}

class _SequenceRecallState extends State<SequenceRecall> {
  // GAME SETTINGS
  static const int totalRounds = 5;
  static const int gameDuration = 60;
  static const int startingSequenceLength = 3;
  static const int maximumSequenceLength = 7;
  static const int previewSeconds = 3;

  // SYMBOL DATA
  final List<String> symbols = [
    '⭐',
    '🔵',
    '🔺',
    '🟩',
    '❤️️',
    '🌙',
    '☀️',
    '🍎',
    '🚀',
    '🐱',
  ];

  // GAME DATA
  List<String> currentSequence = [];
  List<String> playerSequence = [];

  // GAME STATE
  int currentRound = 1;
  int sequenceLength = startingSequenceLength;
  int gameSeconds = gameDuration;
  int previewTime = previewSeconds;
  int correctRounds = 0;
  int wrongRounds = 0;
  int score = 0;
  int xp = 0;

  // FLAGS
  bool showingSequence = true;
  bool playerInput = false;
  bool checkingAnswer = false;
  bool gameEnded = false;
  bool completed = false;
  bool isPaused = false;
  bool roundFeedback = false;
  bool lastRoundCorrect = false;

  // CONTROLLERS
  Timer? timer;
  late ConfettiController confettiController;
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    startNewGame();
  }

  void startNewGame() {
    timer?.cancel();
    currentSequence = [];
    playerSequence = [];
    currentRound = 1;
    sequenceLength = startingSequenceLength;
    gameSeconds = gameDuration;
    previewTime = previewSeconds;
    correctRounds = 0;
    wrongRounds = 0;
    score = 0;
    xp = 0;
    showingSequence = true;
    playerInput = false;
    checkingAnswer = false;
    gameEnded = false;
    completed = false;
    isPaused = false;
    roundFeedback = false;
    lastRoundCorrect = false;

    generateSequence();
    startPreview();
  }

  void restartGame() {
    timer?.cancel();
    audioPlayer.stop();
    setState(() {
      startNewGame();
    });
  }

  void pauseGame() {
    if (gameEnded || completed || isPaused) return;
    timer?.cancel();
    audioPlayer.pause();
    setState(() {
      isPaused = true;
    });
  }

  void resumeGame() {
    if (!isPaused || gameEnded || completed) return;
    setState(() {
      isPaused = false;
    });
    audioPlayer.resume();

    if (showingSequence) {
      startPreview();
    } else {
      startGameTimer();
    }
  }

  void generateSequence() {
    final Random random = Random();
    currentSequence = [];

    while (currentSequence.length < sequenceLength) {
      final String symbol = symbols[random.nextInt(symbols.length)];
      if (currentSequence.isEmpty || currentSequence.last != symbol) {
        currentSequence.add(symbol);
      }
    }
    playerSequence = [];
  }

  void startPreview() {
    timer?.cancel();
    showingSequence = true;
    playerInput = false;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (isPaused) return;

      setState(() {
        previewTime--;
      });

      if (previewTime <= 0) {
        t.cancel();
        setState(() {
          showingSequence = false;
          playerInput = true;
        });
        startGameTimer();
      }
    });
  }

  void startGameTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
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
        endGame(false);
      }
    });
  }

  void selectSymbol(String symbol) {
    if (!playerInput ||
        showingSequence ||
        checkingAnswer ||
        isPaused ||
        gameEnded ||
        completed) {
      return;
    }

    if (playerSequence.length >= sequenceLength) return;

    setState(() {
      playerSequence.add(symbol);
    });

    if (playerSequence.length == sequenceLength) {
      checkAnswer();
    }
  }

  void checkAnswer() {
    if (checkingAnswer || gameEnded) return;

    checkingAnswer = true;
    bool correct = true;

    for (int i = 0; i < currentSequence.length; i++) {
      if (currentSequence[i] != playerSequence[i]) {
        correct = false;
        break;
      }
    }

    if (correct) {
      correctRounds++;
      lastRoundCorrect = true;
      playCorrectSound();
    } else {
      wrongRounds++;
      lastRoundCorrect = false;
      playWrongSound();
    }

    setState(() {
      roundFeedback = true;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (isPaused) {
        checkingAnswer = false;
        return;
      }

      if (correct) {
        if (currentRound >= totalRounds) {
          endGame(true);
          return;
        }
        startNextRound();
      } else {
        endGame(false);
      }
    });
  }

  void startNextRound() {
    currentRound++;
    if (sequenceLength < maximumSequenceLength) {
      sequenceLength++;
    }

    previewTime = previewSeconds;
    playerSequence = [];
    roundFeedback = false;
    lastRoundCorrect = false;
    checkingAnswer = false;
    showingSequence = true;
    playerInput = false;

    generateSequence();
    startPreview();
  }

  void calculateResults() {
    final int timeUsed = gameDuration - gameSeconds;
    int calculatedScore = 1000 - (wrongRounds * 100) - (timeUsed * 3);
    score = calculatedScore < 0 ? 0 : calculatedScore;

    xp = 20;
    if (wrongRounds == 0) xp += 20;
    if (timeUsed <= 30) xp += 10;
  }

  String getGrade() {
    if (score >= 900) return 'S';
    if (score >= 750) return 'A';
    if (score >= 600) return 'B';
    if (score >= 450) return 'C';
    return 'D';
  }

  void endGame(bool win) {
    if (gameEnded || isPaused) return;

    gameEnded = true;
    timer?.cancel();

    if (win) {
      calculateResults();
      confettiController.play();
      playCompleteSound();
    } else {
      score = 0;
      xp = 0;
    }

    setState(() {
      completed = true;
      playerInput = false;
    });

    saveScore(win);
  }

  Future<void> saveScore(bool win) async {
    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Sequence Recall',
        'roundsCompleted': correctRounds,
        'totalRounds': totalRounds,
        'wrongRounds': wrongRounds,
        'score': score,
        'xp': xp,
        'grade': win ? getGrade() : 'F',
        'completed': win,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error saving Sequence Recall score: $e');
    }
  }

  void playCorrectSound() {
    audioPlayer.stop();
    audioPlayer.play(AssetSource('sounds/correct.mp3'));
  }

  void playWrongSound() {
    audioPlayer.stop();
    audioPlayer.play(AssetSource('sounds/wrong.mp3'));
  }

  void playCompleteSound() {
    audioPlayer.stop();
    audioPlayer.play(AssetSource('sounds/level up.mp3'));
  }

  void goToMainMenu() {
    Navigator.pop(context);
  }

  void goToNextLevel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Level 6 will be connected here next!'),
      ),
    );
  }

  // WIDGET BUILDERS

  Widget _buildStatBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(77),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(61)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSequenceDisplay() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        currentSequence.length,
        (index) {
          return Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  offset: Offset(0, 4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                currentSequence[index],
                style: const TextStyle(fontSize: 32),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildPlayerSequence() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        sequenceLength,
        (index) {
          final bool hasValue = index < playerSequence.length;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: hasValue ? const Color(0xFFFF4081) : Colors.black.withAlpha(64),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue ? Colors.white : Colors.white.withAlpha(97),
                width: 2,
              ),
              boxShadow: hasValue
                  ? const [
                      BoxShadow(
                        color: Color(0xFF990033),
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                hasValue ? playerSequence[index] : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: hasValue ? Colors.white : Colors.white.withAlpha(97),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildSymbolButton(String symbol) {
    final bool disabled =
        !playerInput || checkingAnswer || isPaused || gameEnded || completed;

    return GestureDetector(
      onTap: disabled ? null : () => selectSymbol(symbol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: disabled ? Colors.white.withAlpha(31) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled ? Colors.white.withAlpha(61) : const Color(0xFFFFD700),
            width: 2,
          ),
          boxShadow: disabled
              ? null
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 4),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 30,
              color: disabled ? Colors.white.withAlpha(61) : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildResultScreen() {
    final bool passed = xp > 0;
    final int timeUsed = gameDuration - gameSeconds;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(100),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withAlpha(61), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  passed ? '🎉 LEVEL COMPLETE!' : '⏰ TIME IS UP!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  passed
                      ? 'Excellent sequence memory!'
                      : 'You were unable to complete the sequence challenge.',
                  style: TextStyle(fontSize: 15, color: Colors.white.withAlpha(178)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (passed)
                  Text(
                    'Grade: ${getGrade()}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                const SizedBox(height: 15),
                Text(
                  '🏆 Score: $score',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  passed ? '⭐ XP Earned: +$xp' : '⭐ XP Earned: 0',
                  style: TextStyle(fontSize: 18, color: Colors.white.withAlpha(222)),
                ),
                Text(
                  '🧠 Rounds: $correctRounds/$totalRounds',
                  style: TextStyle(fontSize: 18, color: Colors.white.withAlpha(222)),
                ),
                Text(
                  '❌ Wrong Rounds: $wrongRounds',
                  style: TextStyle(fontSize: 18, color: Colors.white.withAlpha(222)),
                ),
                Text(
                  '⏱ Time Used: ${timeUsed}s',
                  style: TextStyle(fontSize: 18, color: Colors.white.withAlpha(222)),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4081),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: restartGame,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Restart Level',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withAlpha(153), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: goToMainMenu,
                    icon: const Icon(Icons.home, color: Colors.white),
                    label: const Text(
                      'Main Menu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (passed) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: goToNextLevel,
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text(
                        'Next Level',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildGameScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBadge(
                showingSequence ? "PREVIEW" : "TIME",
                showingSequence ? "${previewTime}s" : "${gameSeconds}s",
              ),
              _buildStatBadge("ROUND", "$currentRound/$totalRounds"),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            showingSequence ? 'MEMORIZE THE SEQUENCE' : 'REPEAT THE SEQUENCE',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD700),
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            showingSequence
                ? 'Remember the symbols in order.'
                : 'Tap the symbols in the same order.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(178),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          if (showingSequence) buildSequenceDisplay(),
          if (!showingSequence) ...[
            Text(
              'YOUR SEQUENCE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white.withAlpha(178),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            buildPlayerSequence(),
            const SizedBox(height: 25),
            Text(
              'CHOOSE SYMBOLS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white.withAlpha(178),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: symbols
                  .map((symbol) => buildSymbolButton(symbol))
                  .toList(),
            ),
          ],
          if (roundFeedback) ...[
            const SizedBox(height: 20),
            Text(
              lastRoundCorrect ? '✅ CORRECT!' : '❌ WRONG!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: lastRoundCorrect
                    ? const Color(0xFF38EF7D)
                    : const Color(0xFFFF4B2B),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // APP BAR
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _build3DButton(
                          onTap: goToMainMenu,
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(77),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 2,
                            ),
                          ),
                          child: const Text(
                            "SEQUENCE RECALL",
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (!completed)
                          _build3DButton(
                            onTap: pauseGame,
                            child: const Icon(
                              Icons.pause_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          )
                        else
                          const SizedBox(width: 46),
                      ],
                    ),
                  ),

                  Expanded(
                    child: completed ? buildResultScreen() : buildGameScreen(),
                  ),
                ],
              ),

              if (isPaused)
                Positioned.fill(
                  child: PauseMenu(
                    onResume: resumeGame,
                    onRestart: restartGame,
                    onOptions: () {},
                    onMainMenu: goToMainMenu,
                  ),
                ),

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
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    confettiController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}