import 'dart:async';
import 'dart:math';
import 'dart:ui';

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
  // ============================================================
  // SETTINGS
  // ============================================================

  static const int gameDuration = 30; // starting time (seconds)
  static const int previewDuration = 3; // seconds the pattern is shown
  static const int correctBonusSeconds = 5; // time added per completed round
  static const int wrongPenaltySeconds = 5; // time removed per wrong tile

  // The grid is always 3 columns wide and grows downwards.
  // 3 x 5 = 15 tiles is the largest grid.
  static const int gridColumns = 3;
  static const int maxGridRows = 5;
  static const int maxTilesToRemember = 7;

  final Random random = Random();
  final AudioPlayer audioPlayer = AudioPlayer();

  late final ConfettiController confettiController;

  Timer? gameTimer;
  Timer? previewTimer;
  Timer? feedbackTimer;

  // ============================================================
  // GAME STATE
  // ============================================================

  int currentRound = 1;
  int gameSeconds = gameDuration;
  int previewSeconds = previewDuration;

  int roundsCompleted = 0;
  int wrongAttempts = 0;
  int streak = 0;
  int bestStreak = 0;
  int score = 0;
  int xp = 0;

  int gridRows = 3;
  int tilesToRemember = 3;
  int? wrongTileIndex;

  String feedbackText = '';

  List<int> highlightedTiles = [];
  List<int> selectedTiles = [];

  bool showingPattern = true;
  bool isPaused = false;
  bool checkingAnswer = false;
  bool roundFeedback = false;
  bool lastRoundCorrect = false;
  bool gameEnded = false;
  bool isSaving = false;
  bool saveFailed = false;

  int get totalTiles => gridColumns * gridRows;

  // ============================================================
  // INITIALIZATION
  // ============================================================

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

  @override
  void dispose() {
    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    audioPlayer.dispose();
    confettiController.dispose();

    super.dispose();
  }

  // ============================================================
  // GAME SETUP
  // ============================================================

  void _resetGame() {
    currentRound = 1;
    gameSeconds = gameDuration;
    previewSeconds = previewDuration;

    roundsCompleted = 0;
    wrongAttempts = 0;
    streak = 0;
    bestStreak = 0;
    score = 0;
    xp = 0;

    highlightedTiles = [];
    selectedTiles = [];
    wrongTileIndex = null;
    feedbackText = '';

    showingPattern = true;
    isPaused = false;
    checkingAnswer = false;
    roundFeedback = false;
    lastRoundCorrect = false;
    gameEnded = false;
    isSaving = false;
    saveFailed = false;

    _updateDifficulty();
  }

  /// Rounds never end, but the grid stops growing at 15 tiles (3 x 5)
  /// and the number of tiles to remember stops at [maxTilesToRemember].
  void _updateDifficulty() {
    // Rounds 1-2: 3x3 (9 tiles)
    // Rounds 3-4: 3x4 (12 tiles)
    // Round 5+  : 3x5 (15 tiles, the maximum)
    if (currentRound <= 2) {
      gridRows = 3;
    } else if (currentRound <= 4) {
      gridRows = 4;
    } else {
      gridRows = maxGridRows;
    }

    // 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 7 ...
    tilesToRemember = min(
      3 + (currentRound - 1) ~/ 2,
      maxTilesToRemember,
    );
  }

  void _generatePattern() {
    final positions = List<int>.generate(totalTiles, (i) => i);

    positions.shuffle(random);

    highlightedTiles = positions.take(tilesToRemember).toList()..sort();

    selectedTiles = [];
    wrongTileIndex = null;
    previewSeconds = previewDuration;
    showingPattern = true;
  }

  // ============================================================
  // AUDIO
  // ============================================================

  Future<void> _playSound(String fileName) async {
    try {
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Memory Matrix audio error: $e');
    }
  }

  // ============================================================
  // TIMERS
  // ============================================================

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
          _endGame();
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

  // ============================================================
  // PLAYER INPUT
  // ============================================================

  void _toggleTile(int index) {
    if (showingPattern ||
        isPaused ||
        gameEnded ||
        checkingAnswer ||
        roundFeedback) {
      return;
    }

    if (selectedTiles.contains(index)) return;

    // A wrong tile is an immediate mistake.
    if (!highlightedTiles.contains(index)) {
      _handleWrongTile(index);
      return;
    }

    setState(() {
      selectedTiles.add(index);
    });

    // Finding every tile completes the round automatically.
    if (selectedTiles.length == tilesToRemember) {
      _completeRound();
    }
  }

  void _handleWrongTile(int index) {
    if (checkingAnswer || gameEnded) return;

    setState(() {
      wrongAttempts++;
      streak = 0;

      // Time penalty for the mistake.
      gameSeconds = max(0, gameSeconds - wrongPenaltySeconds);

      wrongTileIndex = index;
      checkingAnswer = true;
      roundFeedback = true;
      lastRoundCorrect = false;
      feedbackText = 'WRONG TILE!  •  -${wrongPenaltySeconds}s';
    });

    _playSound('wrong.mp3');

    feedbackTimer?.cancel();
    feedbackTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        if (!mounted || gameEnded) return;

        // The penalty used up the remaining time.
        if (gameSeconds <= 0) {
          _endGame();
          return;
        }

        // Retry the same round with a NEW pattern.
        setState(() {
          _generatePattern();

          roundFeedback = false;
          checkingAnswer = false;
          lastRoundCorrect = false;
          feedbackText = '';
        });

        _startPreviewTimer();
      },
    );
  }

  void _completeRound() {
    if (checkingAnswer || gameEnded) return;

    final nextStreak = streak + 1;
    final streakBonus = nextStreak % 3 == 0 ? 5 : 0;
    final earnedXp = 10 + streakBonus;

    setState(() {
      checkingAnswer = true;
      roundFeedback = true;
      lastRoundCorrect = true;

      roundsCompleted++;
      streak = nextStreak;
      bestStreak = max(bestStreak, streak);
      score += 100;
      xp += earnedXp;

      // Time reward for the correct round.
      gameSeconds += correctBonusSeconds;

      feedbackText = '+$earnedXp XP  •  +${correctBonusSeconds}s';
    });

    _playSound('correct.mp3');

    feedbackTimer?.cancel();
    feedbackTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        if (!mounted || gameEnded) return;
        _nextRound();
      },
    );
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
      feedbackText = '';
    });

    _startPreviewTimer();
  }

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  void _pauseGame() {
    if (gameEnded || isPaused || checkingAnswer || roundFeedback) return;

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

  // ============================================================
  // RESULTS + FIRESTORE
  // ============================================================

  void _endGame() {
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
      isSaving = true;
      saveFailed = false;
    });

    if (roundsCompleted > 0) {
      _playSound('level up.mp3');
      confettiController.play();
    } else {
      _playSound('wrong.mp3');
    }

    _saveScore();
  }

  Future<void> _saveScore() async {
    try {
      final attempts = roundsCompleted + wrongAttempts;
      final accuracy = attempts == 0 ? 0.0 : (roundsCompleted / attempts) * 100;

      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Memory Matrix',
        'roundsCompleted': roundsCompleted,
        'wrongAttempts': wrongAttempts,
        'streak': bestStreak,
        'accuracy': accuracy,
        'score': score,
        'xp': xp,
        'completed': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          isSaving = false;
          saveFailed = false;
        });
      }
    } catch (e) {
      debugPrint('Error saving Memory Matrix score: $e');

      if (mounted) {
        setState(() {
          isSaving = false;
          saveFailed = true;
        });
      }
    }
  }

  // ============================================================
  // RESTART / NAVIGATION
  // ============================================================

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
    final bool pauseDisabled = gameEnded || checkingAnswer || roundFeedback;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'Memory Matrix',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Row(
      children: [
        _buildHudCard(
          icon: Icons.timer_outlined,
          title: 'TIME',
          value: '${gameSeconds}s',
          valueColor: gameSeconds <= 10 ? Colors.redAccent : Colors.cyanAccent,
        ),
        const SizedBox(width: 8),
        _buildHudCard(
          icon: Icons.grid_view_rounded,
          title: 'ROUND',
          value: '$currentRound',
          valueColor: Colors.purpleAccent,
        ),
        const SizedBox(width: 8),
        _buildHudCard(
          icon: Icons.bolt_rounded,
          title: 'XP',
          value: '$xp',
          valueColor: Colors.amber,
        ),
        const SizedBox(width: 8),
        _buildHudCard(
          icon: Icons.local_fire_department,
          title: 'STREAK',
          value: '$streak',
          valueColor: Colors.orangeAccent,
        ),
      ],
    );
  }

  // ============================================================
  // TILES + GRID
  // ============================================================

  Widget _buildTile(int index, double size) {
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

    final bool active = isHighlighted || isSelected || isWrong;

    return GestureDetector(
      onTap: () => _toggleTile(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: active
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
            size: size * 0.42,
            color: active ? const Color(0xFF4A0E4E) : Colors.white24,
          ),
        ),
      ),
    );
  }

  /// The grid always fits the space that is left on the screen,
  /// even when it grows to the maximum of 15 tiles (3 x 5).
  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;

        final maxWidth = min(constraints.maxWidth, 360.0);

        final sizeByWidth = (maxWidth - spacing * (gridColumns - 1)) /
            gridColumns;

        final sizeByHeight = (constraints.maxHeight - spacing * (gridRows - 1)) /
            gridRows;

        final tileSize = max(40.0, min(min(sizeByWidth, sizeByHeight), 100.0));

        final rowWidgets = <Widget>[];

        for (int row = 0; row < gridRows; row++) {
          if (row > 0) rowWidgets.add(const SizedBox(height: spacing));

          final tilesInRow = <Widget>[];

          for (int col = 0; col < gridColumns; col++) {
            if (col > 0) tilesInRow.add(const SizedBox(width: spacing));

            tilesInRow.add(_buildTile(row * gridColumns + col, tileSize));
          }

          rowWidgets.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: tilesInRow,
            ),
          );
        }

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: rowWidgets,
          ),
        );
      },
    );
  }

  // ============================================================
  // FEEDBACK (fixed height so the layout never jumps)
  // ============================================================

  Widget _buildFeedback() {
    final color = lastRoundCorrect ? Colors.greenAccent : Colors.redAccent;

    return SizedBox(
      height: 36,
      child: !roundFeedback || feedbackText.isEmpty
          ? null
          : Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Text(
                feedbackText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
    );
  }

  // ============================================================
  // GAMEPLAY
  // ============================================================

  Widget _buildGameplay() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
      child: Column(
        children: [
          _buildHud(),

          const SizedBox(height: 12),

          Text(
            showingPattern ? 'MEMORIZE THE TILES!' : 'YOUR TURN!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: showingPattern ? Colors.amber : Colors.cyanAccent,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            showingPattern
                ? 'Remember which tiles are glowing.'
                : 'Tap the $tilesToRemember tiles you remember.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            showingPattern
                ? 'Showing for $previewSeconds seconds'
                : 'Correct tiles: ${selectedTiles.length}/$tilesToRemember',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 10),

          Expanded(child: _buildGrid()),

          const SizedBox(height: 8),

          _buildFeedback(),
        ],
      ),
    );
  }

  // ============================================================
  // RESULT SCREEN
  // ============================================================

  Widget _buildStatBadge(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
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

  Widget _buildResultScreen() {
    final bool playedWell = roundsCompleted > 0;
    final attempts = roundsCompleted + wrongAttempts;
    final accuracy = attempts == 0 ? 0.0 : (roundsCompleted / attempts) * 100;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playedWell ? '🎉 TIME\'S UP!' : '⏰ TIME\'S UP!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: playedWell ? Colors.amber : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playedWell
                        ? 'Great memory! You reached round $currentRound.'
                        : 'No rounds completed this time. Try again!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
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
                      '⭐ $xp XP',
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
                      _buildStatBadge('🏆 Score', '$score'),
                      _buildStatBadge('🧠 Rounds', '$roundsCompleted'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBadge('🔥 Best Streak', '$bestStreak'),
                      _buildStatBadge('❌ Mistakes', '$wrongAttempts'),
                      _buildStatBadge(
                        '🎯 Accuracy',
                        '${accuracy.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isSaving)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Saving your score...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  else if (saveFailed)
                    Text(
                      'Your score could not be saved. Check your connection and retry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange.shade200,
                        fontSize: 12,
                      ),
                    )
                  else
                    const Text(
                      'Your score has been saved!',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildChunkyButton(
                    label: 'Play Again',
                    icon: Icons.refresh_rounded,
                    color: const Color(0xFF2EC4B6),
                    onPressed: _restartGame,
                  ),
                  if (saveFailed) ...[
                    const SizedBox(height: 10),
                    _buildChunkyButton(
                      label: 'Retry Saving',
                      icon: Icons.cloud_upload_rounded,
                      color: const Color(0xFFFF9F1C),
                      onPressed: () {
                        setState(() {
                          isSaving = true;
                          saveFailed = false;
                        });
                        _saveScore();
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildChunkyButton(
                    label: 'Main Menu',
                    icon: Icons.home_rounded,
                    color: Colors.white24,
                    onPressed: _goToMainMenu,
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
    return MediaQuery(
      // Stops large system font settings from inflating the layout.
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.0),
      ),
      child: Scaffold(
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
                    child: gameEnded ? _buildResultScreen() : _buildGameplay(),
                  ),
                ],
              ),

              // Pause menu
              if (isPaused && !gameEnded)
                Positioned.fill(
                  child: PauseMenu(
                    onResume: _resumeGame,
                    onRestart: _restartGame,
                    onOptions: () {},
                    onMainMenu: _goToMainMenu,
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
      ),
    );
  }
}