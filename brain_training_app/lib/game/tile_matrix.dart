import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../services/score_identity.dart';
import '../models/game_difficulty.dart';
import '../services/game_audio.dart';
import '../services/game_options_menu.dart';
import '../widgets/pause_menu.dart';
import 'pattern_sequence.dart';

// TODO (Level 6): when Level 6 exists, import it here, e.g.
// import 'level_6_file.dart';

class MemoryMatrix extends StatefulWidget {
  final GameDifficulty difficulty;

  const MemoryMatrix({
    super.key,
    this.difficulty = GameDifficulty.medium,
  });

  @override
  State<MemoryMatrix> createState() => _MemoryMatrixState();
}

class _MemoryMatrixState extends State<MemoryMatrix> {
  // ============================================================
  // SETTINGS
  // ============================================================

  /// Set this to true once Level 6 exists and `goToNextLevel()` below
  /// points at it. While false, only the Previous button is shown.
  static const bool hasNextLevel = false;

  int get gameDuration {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 0;
      case GameDifficulty.medium:
        return 30;
      case GameDifficulty.hard:
        return 20;
    }
  }

  int get previewDuration {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 5;
      case GameDifficulty.medium:
        return 3;
      case GameDifficulty.hard:
        return 2;
    }
  }

  int get correctBonusSeconds {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 0;
      case GameDifficulty.medium:
        return 3;
      case GameDifficulty.hard:
        return 3;
    }
  }

  int get wrongPenaltySeconds {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 0;
      case GameDifficulty.medium:
        return 5;
      case GameDifficulty.hard:
        return 7;
    }
  }

  int get maxTilesToRemember {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 6;
      case GameDifficulty.medium:
        return 7;
      case GameDifficulty.hard:
        return 8;
    }
  }

  int get maxRounds {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 5;
      case GameDifficulty.medium:
        return 7;
      case GameDifficulty.hard:
        return 10;
    }
  }

  bool get hasTimer => widget.difficulty != GameDifficulty.easy;

  static const int gridColumns = 3;
  static const int maxGridRows = 5;

  final Random random = Random();

  final GameAudio audio = GameAudio(
    musicAsset: 'sounds/Recursive_Geometry.mp3',
  );

  late final ConfettiController confettiController;

  Timer? gameTimer;
  Timer? previewTimer;
  Timer? feedbackTimer;

  // ============================================================
  // GAME STATE
  // ============================================================

  int currentRound = 1;
  int gameSeconds = 0;
  int previewSeconds = 0;

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
  bool showOptions = false;
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
    _initAudio();

    // The timer starts only after the preview finishes.
    _startPreviewTimer();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    audio.dispose();
    confettiController.dispose();

    super.dispose();
  }

  // ============================================================
  // AUDIO
  // ============================================================

  Future<void> _initAudio() async {
    await audio.init();

    if (!mounted) return;

    await audio.startMusic();
  }

  // ============================================================
  // GAME SETUP
  // ============================================================

  void _resetGame() {
    // Clear any leftover confetti from a previous game.
    confettiController.stop();

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
    showOptions = false;
    checkingAnswer = false;
    roundFeedback = false;
    lastRoundCorrect = false;
    gameEnded = false;
    isSaving = false;
    saveFailed = false;

    _updateDifficulty();
  }

  /// Adjusts grid size and the number of stars according to difficulty.
  void _updateDifficulty() {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        // Easy: 3x3 for rounds 1-3, then 3x4.
        if (currentRound <= 3) {
          gridRows = 3;
        } else {
          gridRows = 4;
        }
        break;

      case GameDifficulty.medium:
        // Medium: 3x3, then 3x4, then 3x5.
        if (currentRound <= 2) {
          gridRows = 3;
        } else if (currentRound <= 4) {
          gridRows = 4;
        } else {
          gridRows = 5;
        }
        break;

      case GameDifficulty.hard:
        // Hard: reaches the 3x5 grid earlier.
        if (currentRound == 1) {
          gridRows = 3;
        } else if (currentRound <= 3) {
          gridRows = 4;
        } else {
          gridRows = 5;
        }
        break;
    }

    // The number of stars increases every round.
    // Easy:   3, 4, 5, 6, 6
    // Medium: 3, 4, 5, 6, 7, 7, 7
    // Hard:   3, 4, 5, 6, 7, 8, 8, 8, 8, 8
    tilesToRemember = min(
      3 + currentRound - 1,
      maxTilesToRemember,
    );

    // Make sure the number of stars never exceeds the grid size.
    tilesToRemember = min(tilesToRemember, totalTiles);
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
  // TIMERS
  // ============================================================

  /// Starts the countdown only during the player's answering phase.
  /// Easy mode does not use a countdown.
  void _startGameTimer() {
    gameTimer?.cancel();

    if (!hasTimer || gameEnded || isPaused || showingPattern) {
      return;
    }

    gameTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || gameEnded) {
          timer.cancel();
          return;
        }

        if (isPaused || showingPattern) return;

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

  /// Reveals the stars first.
  /// The countdown starts only after the stars disappear.
  void _startPreviewTimer() {
    previewTimer?.cancel();

    // Always stop the countdown during the preview.
    gameTimer?.cancel();

    if (gameEnded || isPaused) return;

    if (previewSeconds <= 0) {
      setState(() {
        showingPattern = false;
      });

      _startGameTimer();
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

          // Start the timer only after the pattern is hidden.
          _startGameTimer();
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

    // Wrong tile immediately counts as a mistake.
    if (!highlightedTiles.contains(index)) {
      _handleWrongTile(index);
      return;
    }

    setState(() {
      selectedTiles.add(index);
    });

    // Complete the round when all stars are found.
    if (selectedTiles.length == tilesToRemember) {
      _completeRound();
    }
  }

  void _handleWrongTile(int index) {
    if (checkingAnswer || gameEnded) return;

    // Pause the countdown during mistake feedback and preview.
    gameTimer?.cancel();

    setState(() {
      wrongAttempts++;
      streak = 0;

      if (hasTimer) {
        gameSeconds = max(0, gameSeconds - wrongPenaltySeconds);
      }

      wrongTileIndex = index;
      checkingAnswer = true;
      roundFeedback = true;
      lastRoundCorrect = false;

      feedbackText = hasTimer
          ? 'WRONG TILE!  •  -${wrongPenaltySeconds}s'
          : 'WRONG TILE!  •  TRY AGAIN';
    });

    audio.playWrong();

    feedbackTimer?.cancel();

    feedbackTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        if (!mounted || gameEnded) return;

        // End the game if the penalty used up the remaining time.
        if (hasTimer && gameSeconds <= 0) {
          _endGame();
          return;
        }

        setState(() {
          _generatePattern();

          roundFeedback = false;
          checkingAnswer = false;
          lastRoundCorrect = false;
          feedbackText = '';
        });

        // Reveal the new pattern before restarting the timer.
        _startPreviewTimer();
      },
    );
  }

  void _completeRound() {
    if (checkingAnswer || gameEnded) return;

    // Stop the countdown during round-completion feedback.
    gameTimer?.cancel();

    final nextStreak = streak + 1;
    final streakBonus = nextStreak % 3 == 0 ? 5 : 0;
    final earnedXp = 10 + streakBonus;

    // Calculate the timer bonus without exceeding the maximum.
    final addedSeconds = hasTimer
        ? min(correctBonusSeconds, gameDuration - gameSeconds)
        : 0;

    setState(() {
      checkingAnswer = true;
      roundFeedback = true;
      lastRoundCorrect = true;

      roundsCompleted++;
      streak = nextStreak;
      bestStreak = max(bestStreak, streak);

      score += 100;
      xp += earnedXp;

      if (hasTimer) {
        // Timer can never exceed the difficulty's starting limit.
        gameSeconds = min(
          gameDuration,
          gameSeconds + correctBonusSeconds,
        );
      }

      feedbackText = hasTimer
          ? '+$earnedXp XP  •  +${addedSeconds}s'
          : '+$earnedXp XP';
    });

    audio.playCorrect();

    feedbackTimer?.cancel();

    feedbackTimer = Timer(
      const Duration(milliseconds: 800),
      () {
        if (!mounted || gameEnded) return;

        // End the game after the required number of rounds.
        if (roundsCompleted >= maxRounds) {
          _endGame();
        } else {
          _nextRound();
        }
      },
    );
  }

  void _nextRound() {
    if (gameEnded || !mounted) return;

    gameTimer?.cancel();

    setState(() {
      currentRound++;

      _updateDifficulty();
      _generatePattern();

      checkingAnswer = false;
      roundFeedback = false;
      lastRoundCorrect = false;
      feedbackText = '';
    });

    // Countdown stays stopped while the new pattern is visible.
    _startPreviewTimer();
  }

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  void _pauseGame() {
    if (gameEnded || isPaused || checkingAnswer || roundFeedback) {
      return;
    }

    previewTimer?.cancel();
    gameTimer?.cancel();

    audio.pauseAll();

    setState(() {
      isPaused = true;
      showOptions = false;
    });
  }

  Future<void> _resumeGame() async {
    if (!isPaused || gameEnded) return;

    setState(() {
      isPaused = false;
      showOptions = false;
    });

    await audio.resume();

    if (!mounted) return;

    if (showingPattern) {
      // Continue showing the remaining preview time.
      _startPreviewTimer();
    } else {
      // Resume the countdown only if the player is answering.
      _startGameTimer();
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
      showOptions = false;
      showingPattern = false;
      checkingAnswer = false;
      roundFeedback = false;
      isSaving = true;
      saveFailed = false;
    });

    audio.stopMusic();

    if (roundsCompleted > 0) {
      audio.playComplete();
      confettiController.play();
    } else {
      audio.playWrong();
    }

    _saveScore();
  }

  Future<void> _saveScore() async {
    try {
      final identityFields = await ScoreIdentity.fields();

      final attempts = roundsCompleted + wrongAttempts;

      final accuracy = attempts == 0
          ? 0.0
          : (roundsCompleted / attempts) * 100;

      await FirebaseFirestore.instance.collection('scores').add({
        ...identityFields,
        'level': 5,
        'levelName': 'Memory Matrix',
        'difficulty': widget.difficulty.label,
        'roundsCompleted': roundsCompleted,
        'maxRounds': maxRounds,
        'wrongAttempts': wrongAttempts,
        'streak': bestStreak,
        'accuracy': accuracy,
        'score': score,
        'xp': xp,
        'completed': roundsCompleted >= maxRounds,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('Memory Matrix score saved successfully.');

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

    audio.stopEffects();

    setState(() {
      _resetGame();
      _generatePattern();
    });

    audio.startMusic();

    // The preview runs first; the timer starts afterward.
    _startPreviewTimer();
  }

  void _goToMainMenu() {
    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    audio.stopMusic();

    Navigator.pop(context);
  }

  // PREVIOUS LEVEL → Level 4: Pattern Sequence (same difficulty)
  void _goToPreviousLevel() {
    gameTimer?.cancel();
    previewTimer?.cancel();
    feedbackTimer?.cancel();

    audio.stopMusic();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PatternSequence(
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  // NEXT LEVEL → Level 6 (same difficulty)
  // TODO: once Level 6 exists, replace the body below with:
  //
  //   gameTimer?.cancel();
  //   previewTimer?.cancel();
  //   feedbackTimer?.cancel();
  //   audio.stopMusic();
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => Level6Screen(difficulty: widget.difficulty),
  //     ),
  //   );
  //
  // ...then set `hasNextLevel = true` at the top of this class.
  void _goToNextLevel() {
    // Not available yet.
  }

  // ============================================================
  // CHUNKY BUTTON
  // ============================================================

  Widget _buildChunkyButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool iconAfterText = false,
  }) {
    final iconWidget = Icon(icon, color: Colors.white, size: 20);
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
              ? [textWidget, const SizedBox(width: 8), iconWidget]
              : [iconWidget, const SizedBox(width: 8), textWidget],
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM APP BAR
  // ============================================================

  Widget _buildCustomAppBar() {
    final bool pauseDisabled =
        gameEnded || checkingAnswer || roundFeedback;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
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
          title: hasTimer ? 'TIME' : 'NO TIMER',
          value: hasTimer ? '${gameSeconds}s' : '∞',
          valueColor: hasTimer
              ? (gameSeconds <= 10
                  ? Colors.redAccent
                  : Colors.cyanAccent)
              : Colors.greenAccent,
        ),
        const SizedBox(width: 8),
        _buildHudCard(
          icon: Icons.grid_view_rounded,
          title: 'ROUND',
          value: '$currentRound/$maxRounds',
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
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
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
            color: active
                ? const Color(0xFF4A0E4E)
                : Colors.white24,
          ),
        ),
      ),
    );
  }

  /// Grid automatically adjusts to the available screen space.
  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;

        final maxWidth = min(constraints.maxWidth, 360.0);

        final sizeByWidth =
            (maxWidth - spacing * (gridColumns - 1)) / gridColumns;

        final sizeByHeight =
            (constraints.maxHeight - spacing * (gridRows - 1)) / gridRows;

        final tileSize = max(
          40.0,
          min(min(sizeByWidth, sizeByHeight), 100.0),
        );

        final rowWidgets = <Widget>[];

        for (int row = 0; row < gridRows; row++) {
          if (row > 0) {
            rowWidgets.add(const SizedBox(height: spacing));
          }

          final tilesInRow = <Widget>[];

          for (int col = 0; col < gridColumns; col++) {
            if (col > 0) {
              tilesInRow.add(const SizedBox(width: spacing));
            }

            tilesInRow.add(
              _buildTile(
                row * gridColumns + col,
                tileSize,
              ),
            );
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
  // FEEDBACK
  // ============================================================

  Widget _buildFeedback() {
    final color =
        lastRoundCorrect ? Colors.greenAccent : Colors.redAccent;

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
                border: Border.all(
                  color: color.withValues(alpha: 0.6),
                ),
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
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + bottomInset,
      ),
      child: Column(
        children: [
          _buildHud(),

          const SizedBox(height: 12),

          Text(
            showingPattern
                ? 'MEMORIZE THE TILES!'
                : 'YOUR TURN!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: showingPattern
                  ? Colors.amber
                  : Colors.cyanAccent,
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

          Expanded(
            child: _buildGrid(),
          ),

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

  /// Previous (and Next, once Level 6 exists) buttons.
  Widget _buildLevelNavButtons() {
    final previousButton = _buildChunkyButton(
      label: 'Previous',
      icon: Icons.arrow_back_rounded,
      color: const Color(0xFF9B8AD6),
      onPressed: _goToPreviousLevel,
    );

    // Until Level 6 exists, Previous takes the full width.
    if (!hasNextLevel) return previousButton;

    return Row(
      children: [
        Expanded(child: previousButton),
        const SizedBox(width: 10),
        Expanded(
          child: _buildChunkyButton(
            label: 'Next',
            icon: Icons.arrow_forward_rounded,
            color: const Color(0xFFFFD700),
            onPressed: _goToNextLevel,
            iconAfterText: true,
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    final bool playedWell = roundsCompleted > 0;
    final bool completedAllRounds = roundsCompleted >= maxRounds;

    final attempts = roundsCompleted + wrongAttempts;

    final accuracy = attempts == 0
        ? 0.0
        : (roundsCompleted / attempts) * 100;

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
                    completedAllRounds
                        ? '🏆 GAME COMPLETED!'
                        : hasTimer
                            ? '⏰ TIME\'S UP!'
                            : '🎮 GAME ENDED!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: completedAllRounds
                          ? Colors.amber
                          : playedWell
                              ? Colors.amber
                              : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    completedAllRounds
                        ? 'Excellent memory! You completed all $maxRounds rounds!'
                        : playedWell
                            ? 'Great memory! You completed $roundsCompleted rounds.'
                            : 'No rounds completed this time. Try again!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Difficulty: ${widget.difficulty.label}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
                      _buildStatBadge(
                        '🧠 Rounds',
                        '$roundsCompleted/$maxRounds',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBadge(
                        '🔥 Best Streak',
                        '$bestStreak',
                      ),
                      _buildStatBadge(
                        '❌ Mistakes',
                        '$wrongAttempts',
                      ),
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

                  // Play Again
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

                  // Previous (+ Next when Level 6 exists), same difficulty
                  _buildLevelNavButtons(),

                  const SizedBox(height: 10),

                  // Main Menu
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
      // Prevents large system font settings from inflating the layout.
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(
          maxScaleFactor: 1.0,
        ),
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
                    child: gameEnded
                        ? _buildResultScreen()
                        : _buildGameplay(),
                  ),
                ],
              ),

              // Pause menu + shared options screen.
              if (isPaused && !gameEnded)
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
                          onResume: _resumeGame,
                          onRestart: _restartGame,
                          onOptions: () {
                            setState(() {
                              showOptions = true;
                            });
                          },
                          onMainMenu: _goToMainMenu,
                        ),
                ),

              // Confetti.
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