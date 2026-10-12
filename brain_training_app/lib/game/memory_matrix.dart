
import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class MemoryMatrix extends StatefulWidget {
  const MemoryMatrix({super.key});

  @override
  State<MemoryMatrix> createState() => _MemoryMatrixState();
}

class _MemoryMatrixState extends State<MemoryMatrix> {
  static const int totalRounds = 5;
  static const int previewDuration = 3;
  static const int gameDuration = 90;
  static const int totalMistakesAllowed = 3;

  final Random random = Random();
  final AudioPlayer audioPlayer = AudioPlayer();

  late final ConfettiController confettiController;

  Timer? gameTimer;
  Timer? previewTimer;
  Timer? feedbackTimer;

  int currentRound = 1;
  int gameSeconds = gameDuration;
  int previewSeconds = previewDuration;

  int correctRounds = 0;
  int wrongAttempts = 0;
  int mistakesRemaining = totalMistakesAllowed;
  int score = 0;
  int xp = 0;

  int gridSize = 3;
  int tilesToRemember = 3;
  int? wrongTileIndex;

  List<int> highlightedTiles = [];
  List<int> selectedTiles = [];

  bool showingPattern = true;
  bool isPaused = false;
  bool checkingAnswer = false;
  bool roundFeedback = false;
  bool lastRoundCorrect = false;
  bool gameEnded = false;
  bool scoreSaved = false;

  @override
  void initState() {
    super.initState();

    confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _resetGame();
    _generatePattern();
    _startGameTimer();
    _startPreviewTimer();
  }

  // ------------------------------------------------------------
  // GAME SETUP
  // ------------------------------------------------------------

  void _resetGame() {
    currentRound = 1;
    gameSeconds = gameDuration;
    previewSeconds = previewDuration;

    correctRounds = 0;
    wrongAttempts = 0;
    mistakesRemaining = totalMistakesAllowed;
    score = 0;
    xp = 0;

    highlightedTiles = [];
    selectedTiles = [];
    wrongTileIndex = null;

    showingPattern = true;
    isPaused = false;
    checkingAnswer = false;
    roundFeedback = false;
    lastRoundCorrect = false;
    gameEnded = false;
    scoreSaved = false;

    _updateDifficulty();
  }

  void _updateDifficulty() {
    if (currentRound <= 3) {
      gridSize = 3;
    } else {
      gridSize = 4;
    }

    switch (currentRound) {
      case 1:
      case 2:
        tilesToRemember = 3;
        break;
      case 3:
        tilesToRemember = 4;
        break;
      case 4:
        tilesToRemember = 5;
        break;
      default:
        tilesToRemember = 6;
    }
  }

  void _generatePattern() {
    final totalTiles = gridSize * gridSize;
    final positions = List<int>.generate(totalTiles, (i) => i);

    positions.shuffle(random);

    highlightedTiles = positions.take(tilesToRemember).toList()
      ..sort();

    selectedTiles = [];
    wrongTileIndex = null;
    previewSeconds = previewDuration;
    showingPattern = true;
  }

  // ------------------------------------------------------------
  // TIMERS
  // ------------------------------------------------------------

  void _startGameTimer() {
    gameTimer?.cancel();

    gameTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || gameEnded) {
          timer.cancel();
          return;
        }

        if (isPaused) return;

        if (gameSeconds <= 1) {
          setState(() {
            gameSeconds = 0;
          });

          timer.cancel();
          _endGame(false);
        } else {
          setState(() {
            gameSeconds--;
          });
        }
      },
    );
  }

  void _startPreviewTimer() {
    previewTimer?.cancel();

    if (previewSeconds <= 0) {
      setState(() {
        showingPattern = false;
      });
      return;
    }

    previewTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || gameEnded) {
          timer.cancel();
          return;
        }

        if (isPaused) return;

        if (previewSeconds <= 1) {
          timer.cancel();

          setState(() {
            previewSeconds = 0;
            showingPattern = false;
          });
        } else {
          setState(() {
            previewSeconds--;
          });
        }
      },
    );
  }

  // ------------------------------------------------------------
  // PLAYER INPUT: EVERY TILE IS CHECKED IMMEDIATELY
  // ------------------------------------------------------------

  void _toggleTile(int index) {
    if (showingPattern ||
        isPaused ||
        gameEnded ||
        checkingAnswer ||
        roundFeedback) {
      return;
    }

    // Do not let the player select the same tile twice.
    if (selectedTiles.contains(index)) return;

    // A wrong tile immediately counts as a mistake.
    if (!highlightedTiles.contains(index)) {
      _handleWrongTile(index);
      return;
    }

    // This is a correct tile. Keep it selected.
    setState(() {
      selectedTiles.add(index);
    });

    // Completing all correct selections automatically
    // completes the round. There is no Check Answer button.
    if (selectedTiles.length == tilesToRemember) {
      _completeRound();
    }
  }

  void _handleWrongTile(int index) {
    if (checkingAnswer || gameEnded) return;

    setState(() {
      wrongAttempts++;
      mistakesRemaining--;

      wrongTileIndex = index;
      checkingAnswer = true;
      roundFeedback = true;
      lastRoundCorrect = false;
    });

    _playSound('wrong.mp3');

    feedbackTimer?.cancel();
    feedbackTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        if (!mounted || gameEnded) return;

        if (mistakesRemaining <= 0) {
          _endGame(false);
          return;
        }

        // Generate a NEW pattern for the retry.
        // _generatePattern() also clears selectedTiles and wrongTileIndex,
        // resets previewSeconds, and sets showingPattern = true.
        setState(() {
          _generatePattern();

          roundFeedback = false;
          checkingAnswer = false;
          lastRoundCorrect = false;
        });

        // Show the new pattern for 3 seconds.
        _startPreviewTimer();
      },
    );
  }

  void _completeRound() {
    if (checkingAnswer || gameEnded) return;

    setState(() {
      checkingAnswer = true;
      roundFeedback = true;
      lastRoundCorrect = true;

      correctRounds++;
      score += 100;
      xp += 10;

      // Completion bonus for the final round.
      if (currentRound == totalRounds) {
        xp += 10;
      }
    });

    _playSound('correct.mp3');

    feedbackTimer?.cancel();
    feedbackTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        if (!mounted || gameEnded) return;

        if (currentRound >= totalRounds) {
          _endGame(true);
        } else {
          _nextRound();
        }
      },
    );
  }

  Future<void> _playSound(String fileName) async {
    try {
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Memory Matrix audio error: $e');
    }
  }

  void _nextRound() {
    if (gameEnded || !mounted) return;

    setState(() {
      currentRound++;
      _updateDifficulty();
      _generatePattern();

      checkingAnswer = false;
      roundFeedback = false;
      lastRoundCorrect = false;
    });

    _startPreviewTimer();
  }

  // ------------------------------------------------------------
  // PAUSE / RESUME
  // ------------------------------------------------------------

  void _pauseGame() {
    if (gameEnded ||
        isPaused ||
        checkingAnswer ||
        roundFeedback) {
      return;
    }

    previewTimer?.cancel();
    gameTimer?.cancel();

    audioPlayer.pause();

    setState(() {
      isPaused = true;
    });
  }

  void _resumeGame() {
    if (!isPaused || gameEnded) return;

    setState(() {
      isPaused = false;
    });

    audioPlayer.resume();

    _startGameTimer();

    if (showingPattern) {
      _startPreviewTimer();
    }
  }

  // ------------------------------------------------------------
  // RESULTS AND FIRESTORE
  // ------------------------------------------------------------

  void _endGame(bool won) {
    if (gameEnded) return;

    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    setState(() {
      gameEnded = true;
      isPaused = false;
      showingPattern = false;
      checkingAnswer = false;
      roundFeedback = false;
    });

    if (won) {
      _playSound('level up.mp3');
      confettiController.play();
    }

    _saveScore(won);
  }

  String _getGrade() {
    if (correctRounds == totalRounds && wrongAttempts == 0) {
      return 'S';
    }
    if (correctRounds >= 4) return 'A';
    if (correctRounds >= 3) return 'B';
    if (correctRounds >= 2) return 'C';
    return 'D';
  }

  Future<void> _saveScore(bool won) async {
    if (scoreSaved) return;
    scoreSaved = true;

    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Memory Matrix',
        'roundsCompleted': correctRounds,
        'totalRounds': totalRounds,
        'wrongAttempts': wrongAttempts,
        'mistakesAllowed': totalMistakesAllowed,
        'score': score,
        'xp': xp,
        'grade': won ? _getGrade() : 'F',
        'completed': won,
        'timeRemaining': gameSeconds,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error saving Memory Matrix score: $e');
    }
  }

  // ------------------------------------------------------------
  // RESTART / NAVIGATION
  // ------------------------------------------------------------

  void _restartGame() {
    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    audioPlayer.stop();

    setState(() {
      _resetGame();
      _generatePattern();
    });

    _startGameTimer();
    _startPreviewTimer();
  }

  void _goToMainMenu() {
    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    Navigator.pop(context);
  }

  // ------------------------------------------------------------
  // UI COMPONENTS
  // ------------------------------------------------------------

    Widget _buildHeader() {
    final bool pauseDisabled = gameEnded || checkingAnswer || roundFeedback;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          // Empty spacer (replaces the back button) so the
          // title stays centered in the header.
          const SizedBox(width: 48),

          const Expanded(
            child: Text(
              'MEMORY MATRIX',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),

          IconButton(
            onPressed: pauseDisabled ? null : _pauseGame,
            icon: Icon(
              Icons.pause_circle_filled,
              color: pauseDisabled
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.amber,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 9,
          horizontal: 3,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final lives = mistakesRemaining > 0
        ? List.filled(mistakesRemaining, '♥').join(' ')
        : '0';

    return Row(
      children: [
        _buildStat(
          'TIME',
          '${gameSeconds}s',
          gameSeconds <= 10 ? Colors.redAccent : Colors.cyanAccent,
        ),
        const SizedBox(width: 5),
        _buildStat(
          'ROUND',
          '$currentRound/$totalRounds',
          Colors.amber,
        ),
        const SizedBox(width: 5),
        _buildStat(
          'XP',
          '$xp',
          Colors.greenAccent,
        ),
        const SizedBox(width: 5),
        _buildStat(
          'LIVES',
          lives,
          Colors.pinkAccent,
        ),
      ],
    );
  }

  Widget _buildTile(int index) {
    final bool isHighlighted =
        showingPattern && highlightedTiles.contains(index);

    final bool isSelected = selectedTiles.contains(index);
    final bool isWrong = wrongTileIndex == index;

    Color tileColor = Colors.white.withValues(alpha: 0.12);
    Color borderColor = Colors.white.withValues(alpha: 0.25);

    if (isWrong) {
      tileColor = Colors.redAccent;
      borderColor = Colors.white;
    } else if (isHighlighted) {
      tileColor = const Color(0xFFFFD700);
      borderColor = Colors.white;
    } else if (isSelected) {
      tileColor = Colors.greenAccent;
      borderColor = Colors.white;
    }

    IconData iconData;

    if (isWrong) {
      iconData = Icons.close_rounded;
    } else if (isHighlighted) {
      iconData = Icons.star_rounded;
    } else if (isSelected) {
      iconData = Icons.check_rounded;
    } else {
      iconData = Icons.circle_outlined;
    }

    return GestureDetector(
      onTap: () => _toggleTile(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          boxShadow: (isHighlighted || isSelected || isWrong)
              ? [
                  BoxShadow(
                    color: tileColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            iconData,
            size: gridSize == 3 ? 28 : 23,
            color: (isHighlighted || isSelected || isWrong)
                ? const Color(0xFF4A0E4E)
                : Colors.white24,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gridSize * gridSize,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) => _buildTile(index),
        ),
      ),
    );
  }

  Widget _buildGameplay() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        children: [
          _buildStats(),
          const SizedBox(height: 18),

          Text(
            showingPattern ? 'MEMORIZE THE TILES!' : 'YOUR TURN!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            showingPattern
                ? 'Remember which tiles are glowing.'
                : 'Tap the $tilesToRemember tiles you remember.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 12),

          if (showingPattern)
            Text(
              'Showing for $previewSeconds seconds',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              'Correct tiles: ${selectedTiles.length}/$tilesToRemember',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),

          const SizedBox(height: 12),

          Center(child: _buildGrid()),

          const SizedBox(height: 16),

          if (roundFeedback)
            Text(
              lastRoundCorrect
                  ? 'ROUND COMPLETE! 🎉'
                  : mistakesRemaining <= 0
                      ? 'NO LIVES LEFT!'
                      : 'WRONG TILE! $mistakesRemaining LIVES LEFT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: lastRoundCorrect
                    ? Colors.greenAccent
                    : Colors.redAccent,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),

          const SizedBox(height: 12),

          Text(
            'Rounds completed: $correctRounds/$totalRounds',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Choose carefully. Every wrong tile costs one life.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final bool won = correctRounds == totalRounds;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? '🎉 LEVEL COMPLETE!' : '🧠 GOOD TRY!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                won
                    ? 'Amazing visual memory!'
                    : 'Keep practicing to improve your memory.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              if (won)
                Text(
                  'GRADE: ${_getGrade()}',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),

              const SizedBox(height: 12),

              _resultRow(
                'Rounds completed',
                '$correctRounds/$totalRounds',
              ),
              _resultRow('Score', '$score'),
              _resultRow('XP earned', '+$xp'),
              _resultRow('Wrong tiles', '$wrongAttempts'),
              _resultRow('Lives remaining', '$mistakesRemaining'),
              _resultRow('Time remaining', '${gameSeconds}s'),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('PLAY AGAIN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4081),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goToMainMenu,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('MAIN MENU'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

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
                  _buildHeader(),
                  Expanded(
                    child: gameEnded
                        ? _buildResultScreen()
                        : _buildGameplay(),
                  ),
                ],
              ),

              if (isPaused)
                Positioned.fill(
                  child: PauseMenu(
                    onResume: _resumeGame,
                    onRestart: _restartGame,
                    onOptions: () {},
                    onMainMenu: _goToMainMenu,
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
                    Colors.amber,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    audioPlayer.dispose();
    confettiController.dispose();

    super.dispose();
  }
}
