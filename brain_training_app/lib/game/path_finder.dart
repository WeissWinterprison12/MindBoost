
import 'dart:async';
import 'dart:math';

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

  static const Color backgroundColor = Color(0xFF10091F);
  static const Color panelColor = Color(0xFF21143A);
  static const Color cyanColor = Color(0xFF64E7FF);
  static const Color greenColor = Color(0xFF55E6A5);
  static const Color goldColor = Color(0xFFFFD166);
  static const Color redColor = Color(0xFFFF6B81);

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
  bool isSaving = false;
  bool isDragging = false;
  bool hasStarted = false;

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
    showTryAgain = false;
    isDragging = false;
    secondsRemaining = previewTimeLimit;
    hasStarted = true;

    if (mounted) setState(() {});
    _startTimer();
  }

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

  void _handlePanStart(DragStartDetails details, double boardSize) {
    if (isPaused ||
        isGameOver ||
        isPreview ||
        isMistakeReveal ||
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
    final distance =
        (cell.x - last.x).abs() + (cell.y - last.y).abs();

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
    _playSound('timeout.mp3');

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
    _playSound('correct.mp3');

    roundsCompleted++;

    final timeBonus =
        secondsRemaining >= (solveTimeLimit ~/ 2) ? 10 : 0;
    xp += 20 + timeBonus;

    if (roundsCompleted >= maxRounds) {
      _playSound('level_complete.mp3');
      confettiController.play();
      _finishGame();
      return;
    }

    setState(() {
      currentRound++;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || isGameOver) return;
      _prepareRound();
    });
  }

  void pauseGame() {
    if (isGameOver || isPaused) return;

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
      isSaving = false;
      isDragging = false;
    });

    _prepareRound();
  }

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
      isSaving = true;
    });

    final grade = _gradeForAccuracy(accuracy);

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
      });
    } catch (error) {
      debugPrint('Could not save Path Finder score: $error');
    }

    if (mounted) setState(() => isSaving = false);
  }

  Widget _buildLives() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(startingLives, (index) {
        return Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Icon(
            Icons.favorite_rounded,
            color: index < lives ? redColor : Colors.white24,
            size: 21,
          ),
        );
      }),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: cyanColor, size: 19),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final boardSize = max(0.0, available);

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
              child: CustomPaint(
                painter: _MazePainter(
                  maze: maze,
                  size: mazeSize,
                  start: start,
                  goal: goal,
                  tracedPath: tracedPath,
                  revealMaze: isPreview || isMistakeReveal,
                  isPreview: isPreview && !isMistakeReveal,
                  showTryAgain: showTryAgain,
                  backgroundColor: backgroundColor,
                  wallColor: const Color(0xFF4B3472),
                  corridorColor: const Color(0xFF211632),
                  cyanColor: cyanColor,
                  greenColor: greenColor,
                  goldColor: goldColor,
                  redColor: redColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults() {
    final grade = _gradeForAccuracy(accuracy);
    final fullyCompleted = roundsCompleted == maxRounds;

    return Container(
      color: backgroundColor,
      width: double.infinity,
      child: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 8,
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      fullyCompleted
                          ? Icons.emoji_events_rounded
                          : Icons.psychology_alt_rounded,
                      color: goldColor,
                      size: 76,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullyCompleted ? 'PATH MASTER!' : 'NICE TRY!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fullyCompleted
                          ? 'You remembered every maze!'
                          : 'Every attempt helps train your memory.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: panelColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: cyanColor.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            grade,
                            style: const TextStyle(
                              color: goldColor,
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'FINAL GRADE',
                            style: TextStyle(
                              color: Colors.white60,
                              letterSpacing: 2,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _resultRow(
                            'Mazes completed',
                            '$roundsCompleted / $maxRounds',
                          ),
                          _resultRow('Total moves', '$totalMoves'),
                          _resultRow('Trace mistakes', '$mistakes'),
                          _resultRow('Lives remaining', '$lives'),
                          _resultRow('XP earned', '+$xp'),
                          _resultRow(
                            'Completion',
                            '${accuracy.toStringAsFixed(0)}%',
                          ),
                          if (isSaving)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: CircularProgressIndicator(
                                color: cyanColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: restartGame,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('PLAY AGAIN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanColor,
                          foregroundColor: backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.grid_view_rounded),
                        label: const Text('LEVEL SELECT'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isGameOver) return _buildResults();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        color: cyanColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PATH FINDER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'Level 8 • Memory Challenge',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Pause',
                        onPressed: pauseGame,
                        icon: const Icon(
                          Icons.pause_circle_filled_rounded,
                          color: cyanColor,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStat(
                        'ROUND',
                        '$currentRound/$maxRounds',
                        Icons.flag_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStat(
                        'TIME',
                        '${secondsRemaining}s',
                        Icons.timer_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStat(
                        'XP',
                        '$xp',
                        Icons.bolt_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'LIVES',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      _buildLives(),
                      const Spacer(),
                      Text(
                        isMistakeReveal
                            ? 'Review your mistake'
                            : isPreview
                                ? 'MEMORIZE THE MAZE'
                                : 'TRACE TO THE FINISH',
                        style: TextStyle(
                          color: showTryAgain ? redColor : cyanColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF180F2B),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: _buildGameBoard(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey<String>(
                        showTryAgain
                            ? 'mistake'
                            : isPreview
                                ? 'preview'
                                : 'trace',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: showTryAgain
                            ? redColor.withOpacity(0.12)
                            : panelColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: showTryAgain
                              ? redColor.withOpacity(0.6)
                              : Colors.white10,
                        ),
                      ),
                      child: Text(
                        showTryAgain
                            ? 'TRY AGAIN! Study the revealed maze.'
                            : isPreview
                                ? 'Memorize the route before the maze hides.'
                                : 'Drag from START through the corridors to FINISH.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: showTryAgain
                              ? redColor
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    );
  }
}

class _MazePainter extends CustomPainter {
  final List<List<bool>> maze;
  final int size;
  final Point<int> start;
  final Point<int> goal;
  final List<Point<int>> tracedPath;
  final bool revealMaze;
  final bool isPreview;
  final bool showTryAgain;
  final Color backgroundColor;
  final Color wallColor;
  final Color corridorColor;
  final Color cyanColor;
  final Color greenColor;
  final Color goldColor;
  final Color redColor;

  _MazePainter({
    required this.maze,
    required this.size,
    required this.start,
    required this.goal,
    required this.tracedPath,
    required this.revealMaze,
    required this.isPreview,
    required this.showTryAgain,
    required this.backgroundColor,
    required this.wallColor,
    required this.corridorColor,
    required this.cyanColor,
    required this.greenColor,
    required this.goldColor,
    required this.redColor,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (size <= 0) return;

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

        paint.color = revealMaze
            ? (maze[y][x] ? corridorColor : wallColor)
            : const Color(0xFF241A35);

        canvas.drawRect(rect, paint);

        paint
          ..color = Colors.white.withOpacity(0.035)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;

        canvas.drawRect(rect, paint);
        paint.style = PaintingStyle.fill;
      }
    }

    // Draw the player's route.
    if (tracedPath.isNotEmpty) {
      final pathPaint = Paint()
        ..color = showTryAgain ? redColor : cyanColor
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

    _drawMarker(canvas, start, cellSize, greenColor, 'S');
    _drawMarker(canvas, goal, cellSize, goldColor, 'F');

    if (showTryAgain) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'TRY AGAIN!',
          style: TextStyle(
            color: redColor,
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

    final paint = Paint()..color = color;
    canvas.drawCircle(center, cellSize * 0.37, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFF160E25),
          fontSize: cellSize * 0.45,
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
