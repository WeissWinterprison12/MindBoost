import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class PathFinder extends StatefulWidget {
  const PathFinder({super.key});

  @override
  State<PathFinder> createState() => _PathFinderState();
}

class _PathFinderState extends State<PathFinder> {
  static const int maxRounds = 5;
  static const int startingLives = 3;

  // Maze colors (purple theme, same family as the other levels).
  static const Color wallColor = Color(0xFF3A0F52);
  static const Color corridorColor = Color(0xFFEDE3FF);
  static const Color startColor = Color(0xFF38EF7D);
  static const Color finishColor = Color(0xFFFFD700);

  final Random random = Random();
  final AudioPlayer audioPlayer = AudioPlayer();
  final ConfettiController confettiController =
      ConfettiController(duration: const Duration(seconds: 3));

  // Keep track of maze layouts used during this game session.
  final Set<String> usedMazeSignatures = {};

  Timer? gameTimer;

  int currentRound = 1;
  int lives = startingLives;
  int secondsRemaining = 8;
  int roundsCompleted = 0;
  int totalMoves = 0;
  int mistakes = 0;
  int xp = 0;

  int mazeSize = 7;
  int solveTimeLimit = 45;
  int previewTimeLimit = 8;

  List<List<bool>> maze = [];
  List<Point<int>> tracedPath = [];

  final Point<int> start = const Point<int>(1, 1);
  Point<int> goal = const Point<int>(5, 5);

  bool isPreview = true;
  bool isMistakeReveal = false;
  bool showTryAgain = false;
  bool isPaused = false;
  bool isGameOver = false;
  bool isDragging = false;
  bool hasStarted = false;
  bool isRoundComplete = false;

  @override
  void initState() {
    super.initState();
    _prepareRound();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    audioPlayer.dispose();
    confettiController.dispose();
    super.dispose();
  }

  // ============================================================
  // ROUND SETTINGS
  // ============================================================

  // Each round uses a larger maze.
  int _sizeForRound(int round) {
    switch (round) {
      case 1:
        return 7;
      case 2:
        return 9;
      case 3:
        return 11;
      case 4:
        return 13;
      default:
        return 15;
    }
  }

  int _previewSecondsForRound(int round) {
    return max(4, 9 - round);
  }

  int _solveSecondsForRound(int round) {
    return 50 - (round * 5);
  }

  void _prepareRound() {
    if (isGameOver || lives <= 0) return;

    gameTimer?.cancel();

    mazeSize = _sizeForRound(currentRound);
    goal = Point<int>(mazeSize - 2, mazeSize - 2);

    previewTimeLimit = _previewSecondsForRound(currentRound);
    solveTimeLimit = _solveSecondsForRound(currentRound);

    // Generate a fresh maze for every new attempt.
    maze = _generateFreshMaze(mazeSize);
    tracedPath = [start];

    isPreview = true;
    isMistakeReveal = false;
    isRoundComplete = false;
    showTryAgain = false;
    isDragging = false;
    secondsRemaining = previewTimeLimit;
    hasStarted = true;

    if (mounted) setState(() {});
    _startTimer();
  }

  // ============================================================
  // MAZE GENERATION
  // ============================================================

  // Generates a maze using randomized depth-first search.
  // true = corridor; false = wall.
  List<List<bool>> _generateMaze(int size) {
    final grid = List.generate(
      size,
      (_) => List<bool>.filled(size, false),
    );

    final visited = <Point<int>>{};
    final stack = <Point<int>>[start];

    grid[start.y][start.x] = true;
    visited.add(start);

    const directions = <Point<int>>[
      Point<int>(0, -2),
      Point<int>(0, 2),
      Point<int>(-2, 0),
      Point<int>(2, 0),
    ];

    while (stack.isNotEmpty) {
      final current = stack.last;
      final neighbors = <Point<int>>[];

      for (final direction in directions) {
        final next = Point<int>(
          current.x + direction.x,
          current.y + direction.y,
        );

        if (next.x > 0 &&
            next.y > 0 &&
            next.x < size - 1 &&
            next.y < size - 1 &&
            !visited.contains(next)) {
          neighbors.add(next);
        }
      }

      if (neighbors.isEmpty) {
        stack.removeLast();
        continue;
      }

      final next = neighbors[random.nextInt(neighbors.length)];

      final middle = Point<int>(
        (current.x + next.x) ~/ 2,
        (current.y + next.y) ~/ 2,
      );

      grid[middle.y][middle.x] = true;
      grid[next.y][next.x] = true;

      visited.add(next);
      stack.add(next);
    }

    grid[start.y][start.x] = true;
    grid[goal.y][goal.x] = true;

    return grid;
  }

  // Avoid reusing a layout within this session when possible.
  List<List<bool>> _generateFreshMaze(int size) {
    for (int attempt = 0; attempt < 100; attempt++) {
      final candidate = _generateMaze(size);

      final signature = candidate
          .map((row) => row.map((cell) => cell ? '1' : '0').join())
          .join();

      if (usedMazeSignatures.add(signature)) {
        return candidate;
      }
    }

    // Fallback: still a valid randomized maze.
    return _generateMaze(size);
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startTimer() {
    gameTimer?.cancel();

    gameTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || isPaused || isGameOver) return;

        // A wrong move reveals the maze briefly.
        // When that reveal expires, remove one life and generate
        // a fresh maze for the same round.
        if (isMistakeReveal) {
          if (secondsRemaining > 1) {
            setState(() => secondsRemaining--);
          } else {
            _resolveFailedAttempt();
          }
          return;
        }

        if (secondsRemaining > 1) {
          setState(() => secondsRemaining--);
          return;
        }

        if (isPreview) {
          // The preview has ended. Hide the maze and start solving.
          setState(() {
            isPreview = false;
            secondsRemaining = solveTimeLimit;
          });
          return;
        }

        // The player ran out of solving time.
        _loseLifeForTimeout();
      },
    );
  }

  Future<void> _playSound(String filename) async {
    try {
      await audioPlayer.stop();
      await audioPlayer.play(AssetSource('sounds/$filename'));
    } catch (_) {
      // Missing audio should not break gameplay.
    }
  }

  // ============================================================
  // TRACING INPUT
  // ============================================================

  void _handlePanStart(DragStartDetails details, double boardSize) {
    if (isPaused ||
        isGameOver ||
        isPreview ||
        isMistakeReveal ||
        isRoundComplete ||
        !hasStarted ||
        tracedPath.isEmpty) {
      return;
    }

    final cell = _positionToCell(details.localPosition, boardSize);
    if (cell == null) return;

    // The drag must begin at START or the current endpoint.
    if (cell == tracedPath.last) {
      setState(() => isDragging = true);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, double boardSize) {
    if (!isDragging ||
        isPaused ||
        isGameOver ||
        isPreview ||
        isMistakeReveal ||
        isRoundComplete ||
        tracedPath.isEmpty) {
      return;
    }

    final cell = _positionToCell(details.localPosition, boardSize);
    if (cell == null || cell == tracedPath.last) return;

    final last = tracedPath.last;

    // Allow the player to backtrack one step.
    if (tracedPath.length >= 2 &&
        cell == tracedPath[tracedPath.length - 2]) {
      setState(() {
        tracedPath.removeLast();
        totalMoves++;
      });
      return;
    }

    // Only orthogonally adjacent cells are valid.
    // Ignore skipped cells because fast finger movement can cause
    // Flutter to report pointer updates several cells apart.
    final distance = (cell.x - last.x).abs() + (cell.y - last.y).abs();

    if (distance != 1) return;

    // Hitting a wall reveals the complete maze.
    if (!_isWalkable(cell)) {
      _triggerMistake();
      return;
    }

    setState(() {
      tracedPath.add(cell);
      totalMoves++;
    });

    if (cell == goal) {
      _completeRound();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (mounted) setState(() => isDragging = false);
  }

  Point<int>? _positionToCell(Offset position, double boardSize) {
    if (position.dx < 0 ||
        position.dy < 0 ||
        position.dx >= boardSize ||
        position.dy >= boardSize) {
      return null;
    }

    final cellSize = boardSize / mazeSize;
    final x = (position.dx / cellSize).floor();
    final y = (position.dy / cellSize).floor();

    if (x < 0 || y < 0 || x >= mazeSize || y >= mazeSize) {
      return null;
    }

    return Point<int>(x, y);
  }

  bool _isWalkable(Point<int> point) {
    if (point.x < 0 ||
        point.y < 0 ||
        point.x >= mazeSize ||
        point.y >= mazeSize) {
      return false;
    }

    return maze[point.y][point.x];
  }

  // ============================================================
  // MISTAKES / ROUND RESULTS
  // ============================================================

  // Wrong path: show the maze first.
  // Do not deduct a life until the reveal finishes.
  void _triggerMistake() {
    if (isMistakeReveal || isPreview || isGameOver) return;

    mistakes++;
    _playSound('wrong.mp3');

    setState(() {
      isDragging = false;
      isPreview = true;
      isMistakeReveal = true;
      showTryAgain = true;
      secondsRemaining = 2;
    });

    _startTimer();
  }

  // After the two-second reveal, remove one heart and retry
  // the SAME round with a fresh maze.
  void _resolveFailedAttempt() {
    if (isGameOver || !isMistakeReveal) return;

    gameTimer?.cancel();

    lives = max(0, lives - 1);

    if (lives == 0) {
      _finishGame();
      return;
    }

    _prepareRound();
  }

  // Timeout costs one heart and also creates a new maze.
  void _loseLifeForTimeout() {
    if (isGameOver) return;

    gameTimer?.cancel();
    _playSound('wrong.mp3');

    lives = max(0, lives - 1);

    if (lives == 0) {
      _finishGame();
      return;
    }

    _prepareRound();
  }

  void _completeRound() {
    if (isGameOver) return;

    gameTimer?.cancel();

    isRoundComplete = true;
    isDragging = false;

    roundsCompleted++;

    final timeBonus = secondsRemaining >= (solveTimeLimit ~/ 2) ? 10 : 0;
    xp += 20 + timeBonus;

    if (roundsCompleted >= maxRounds) {
      _playSound('level up.mp3');
      confettiController.play();
      _finishGame();
      return;
    }

    _playSound('correct.mp3');

    setState(() {
      currentRound++;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || isGameOver) return;
      _prepareRound();
    });
  }

  // ============================================================
  // PAUSE / RESTART / NAVIGATION
  // ============================================================

  void pauseGame() {
    if (isGameOver || isPaused || isRoundComplete) return;

    gameTimer?.cancel();
    setState(() => isPaused = true);
  }

  void resumeGame() {
    if (isGameOver || !isPaused) return;

    setState(() => isPaused = false);
    _startTimer();
  }

  void restartGame() {
    gameTimer?.cancel();
    audioPlayer.stop();

    usedMazeSignatures.clear();

    setState(() {
      currentRound = 1;
      lives = startingLives;
      roundsCompleted = 0;
      totalMoves = 0;
      mistakes = 0;
      xp = 0;
      isPaused = false;
      isGameOver = false;
      isDragging = false;
      isRoundComplete = false;
    });

    _prepareRound();
  }

  void goToMainMenu() {
    gameTimer?.cancel();
    Navigator.pop(context);
  }

  // ============================================================
  // SCORE / FIRESTORE
  // ============================================================

  String _gradeForAccuracy(double accuracy) {
    if (accuracy >= 90) return 'S';
    if (accuracy >= 80) return 'A';
    if (accuracy >= 70) return 'B';
    if (accuracy >= 60) return 'C';
    return 'D';
  }

  double get accuracy => (roundsCompleted / maxRounds) * 100;

  Future<void> _finishGame() async {
    if (isGameOver) return;

    gameTimer?.cancel();

    setState(() {
      isGameOver = true;
      isPaused = false;
    });

    final grade = _gradeForAccuracy(accuracy);

    // Saved in the background. The results screen never waits for it,
    // so a missing or slow database cannot freeze the game.
    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 8,
        'levelName': 'Path Finder',
        'completed': roundsCompleted == maxRounds,
        'roundsCompleted': roundsCompleted,
        'totalRounds': maxRounds,
        'moves': totalMoves,
        'wallBumps': mistakes,
        'livesRemaining': lives,
        'xp': xp,
        'accuracy': accuracy,
        'grade': grade,
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Could not save Path Finder score: $error');
    }
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
        width: double.infinity,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Empty spacer so the title badge stays centered.
          const SizedBox(width: 48),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'Path Finder',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          if (!isGameOver)
            IconButton(
              onPressed: isRoundComplete ? null : pauseGame,
              icon: Icon(
                Icons.pause_circle_filled,
                color: isRoundComplete
                    ? Colors.amber.withValues(alpha: 0.4)
                    : Colors.amber,
                size: 32,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ============================================================
  // HUD
  // ============================================================

  Widget _buildHudCard({
    required IconData icon,
    required String title,
    required Widget value,
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
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
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: value,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hudText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildHearts() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(startingLives, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            Icons.favorite_rounded,
            color: index < lives ? Colors.redAccent : Colors.white24,
            size: 17,
          ),
        );
      }),
    );
  }

  Widget _buildHud() {
    final Color timeColor = isMistakeReveal
        ? Colors.redAccent
        : isPreview
            ? Colors.amber
            : (secondsRemaining <= 5 ? Colors.redAccent : Colors.cyanAccent);

    return Row(
      children: [
        _buildHudCard(
          icon: Icons.flag_rounded,
          title: 'ROUND',
          value: _hudText('$currentRound/$maxRounds', Colors.amber),
        ),
        const SizedBox(width: 8),
        _buildHudCard(
          icon: Icons.timer_outlined,
          title: 'TIME',
          value: _hudText('${secondsRemaining}s', timeColor),
        ),
        const SizedBox(width: 8),
        _buildHudCard(
          icon: Icons.bolt_rounded,
          title: 'XP',
          value: _hudText('$xp', Colors.greenAccent),
        ),
        const SizedBox(width: 8),
        _buildHudCard(
          icon: Icons.favorite_rounded,
          title: 'LIVES',
          value: _buildHearts(),
        ),
      ],
    );
  }

  // ============================================================
  // GAMEPLAY
  // ============================================================

  Widget _buildGameplay() {
    final String title = isMistakeReveal
        ? 'TRY AGAIN!'
        : isPreview
            ? 'MEMORIZE THE MAZE'
            : 'TRACE TO THE FINISH';

    final Color titleColor = isMistakeReveal
        ? Colors.redAccent
        : isPreview
            ? Colors.amber
            : Colors.cyanAccent;

    final String hint = isMistakeReveal
        ? 'Study the revealed maze.'
        : isPreview
            ? 'Memorize the route before the maze hides.'
            : 'Drag from START (S) through the corridors to FINISH (F).';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _buildHud(),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, area) {
                // Leave room for the title above and hint below.
                final double boardSize = max(
                  0.0,
                  min(
                    min(area.maxWidth * 0.98, area.maxHeight - 90),
                    420.0,
                  ),
                );

                return Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        _buildBoard(boardSize),
                        const SizedBox(height: 10),
                        Text(
                          hint,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(double outerSize) {
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The exact drawing area, so touch positions line up
            // perfectly with the maze cells.
            final double boardSize = max(
              0.0,
              min(constraints.maxWidth, constraints.maxHeight),
            );

            return Center(
              child: SizedBox(
                width: boardSize,
                height: boardSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) =>
                      _handlePanStart(details, boardSize),
                  onPanUpdate: (details) =>
                      _handlePanUpdate(details, boardSize),
                  onPanEnd: _handlePanEnd,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomPaint(
                      painter: _MazePainter(
                        maze: maze,
                        size: mazeSize,
                        start: start,
                        goal: goal,
                        tracedPath: tracedPath,
                        revealMaze: isPreview || isMistakeReveal,
                        showTryAgain: showTryAgain,
                        wallColor: wallColor,
                        corridorColor: corridorColor,
                        hiddenColor: Colors.white.withValues(alpha: 0.14),
                        pathColor: Colors.cyanAccent,
                        mistakePathColor: Colors.redAccent,
                        startColor: startColor,
                        finishColor: finishColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
    final String grade = _gradeForAccuracy(accuracy);
    final bool fullyCompleted = roundsCompleted == maxRounds;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fullyCompleted ? '🎉 LEVEL COMPLETE!' : '💔 OUT OF LIVES!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: fullyCompleted ? Colors.amber : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    fullyCompleted
                        ? 'You remembered every maze!'
                        : 'Every attempt helps train your memory.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                      'GRADE: $grade',
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
                      _buildStatBadge(
                        '🧭 Mazes',
                        '$roundsCompleted/$maxRounds',
                      ),
                      _buildStatBadge('❤️ Lives', '$lives'),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    '👣 Moves: $totalMoves   •   🧱 Wall bumps: $mistakes',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildChunkyButton(
                    label: 'Play Again',
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
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildCustomAppBar(),
                  Expanded(
                    child: isGameOver
                        ? _buildResultScreen()
                        : _buildGameplay(),
                  ),
                ],
              ),

              // PAUSE MENU
              if (isPaused)
                Positioned.fill(
                  child: PauseMenu(
                    onResume: resumeGame,
                    onRestart: restartGame,
                    onOptions: () {},
                    onMainMenu: goToMainMenu,
                  ),
                ),

              // CONFETTI
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

// ============================================================
// MAZE PAINTER
// ============================================================

class _MazePainter extends CustomPainter {
  final List<List<bool>> maze;
  final int size;
  final Point<int> start;
  final Point<int> goal;
  final List<Point<int>> tracedPath;
  final bool revealMaze;
  final bool showTryAgain;
  final Color wallColor;
  final Color corridorColor;
  final Color hiddenColor;
  final Color pathColor;
  final Color mistakePathColor;
  final Color startColor;
  final Color finishColor;

  _MazePainter({
    required this.maze,
    required this.size,
    required this.start,
    required this.goal,
    required this.tracedPath,
    required this.revealMaze,
    required this.showTryAgain,
    required this.wallColor,
    required this.corridorColor,
    required this.hiddenColor,
    required this.pathColor,
    required this.mistakePathColor,
    required this.startColor,
    required this.finishColor,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (size <= 0 || maze.length != size) return;

    final cellSize = canvasSize.width / size;
    final paint = Paint()..style = PaintingStyle.fill;

    // When hidden, walls and corridors look identical.
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );

        paint
          ..style = PaintingStyle.fill
          ..color = revealMaze
              ? (maze[y][x] ? corridorColor : wallColor)
              : hiddenColor;

        canvas.drawRect(rect, paint);

        paint
          ..color = Colors.white.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;

        canvas.drawRect(rect, paint);
      }
    }

    // Draw the player's route.
    if (tracedPath.isNotEmpty) {
      final pathPaint = Paint()
        ..color = showTryAgain ? mistakePathColor : pathColor
        ..strokeWidth = cellSize * 0.42
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final first = tracedPath.first;

      path.moveTo(
        (first.x + 0.5) * cellSize,
        (first.y + 0.5) * cellSize,
      );

      for (int i = 1; i < tracedPath.length; i++) {
        final point = tracedPath[i];
        path.lineTo(
          (point.x + 0.5) * cellSize,
          (point.y + 0.5) * cellSize,
        );
      }

      canvas.drawPath(path, pathPaint);
    }

    _drawMarker(canvas, start, cellSize, startColor, 'S');
    _drawMarker(canvas, goal, cellSize, finishColor, 'F');

    if (showTryAgain) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'TRY AGAIN!',
          style: TextStyle(
            color: mistakePathColor,
            fontSize: min(22.0, cellSize * 1.2),
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: canvasSize.width);

      textPainter.paint(
        canvas,
        Offset(
          (canvasSize.width - textPainter.width) / 2,
          8,
        ),
      );
    }
  }

  void _drawMarker(
    Canvas canvas,
    Point<int> point,
    double cellSize,
    Color color,
    String label,
  ) {
    final center = Offset(
      (point.x + 0.5) * cellSize,
      (point.y + 0.5) * cellSize,
    );

    // White ring so the marker stands out on any cell color.
    canvas.drawCircle(
      center,
      cellSize * 0.41,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      cellSize * 0.34,
      Paint()..color = color,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFF2E0854),
          fontSize: cellSize * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MazePainter oldDelegate) => true;
}