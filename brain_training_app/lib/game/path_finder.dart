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
  static const int maxRounds = 10;
  static const int startingLives = 3;

  final Random _random = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late ConfettiController confettiController;
  late List<List<bool>> maze;

  Timer? roundTimer;

  // The player's position uses x = column and y = row.
  Point<int> player = const Point<int>(1, 1);
  Point<int> goal = const Point<int>(5, 5);

  int roundsCompleted = 0;
  int secondsRemaining = 38;
  int lives = startingLives;
  int moves = 0;
  int wallBumps = 0;
  int xp = 0;
  int bestRoundTime = 0;

  bool isPaused = false;
  bool gameOver = false;
  bool _scoreSaved = false;

  String feedbackText = 'Swipe to find the exit!';
  Color feedbackColor = Colors.white;

  int get currentRound => roundsCompleted + 1;

  // Rounds 1-2: 7x7, 3-4: 9x9, through 15x15.
  int get mazeSize =>
      min(15, 7 + (roundsCompleted ~/ 2) * 2);

  int get roundTimeLimit =>
      max(20, 38 - (roundsCompleted * 2));

  double get accuracy {
    return (roundsCompleted / maxRounds) * 100;
  }

  String getGrade() {
    if (accuracy >= 90) return 'S';
    if (accuracy >= 80) return 'A';
    if (accuracy >= 70) return 'B';
    if (accuracy >= 60) return 'C';
    return 'D';
  }

  @override
  void initState() {
    super.initState();

    confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _generateMaze();
    secondsRemaining = roundTimeLimit;
    _startRoundTimer(resetTime: false);
  }

  // ------------------------------------------------------------
  // MAZE GENERATION
  // ------------------------------------------------------------

  void _generateMaze() {
    final size = mazeSize;

    // true = wall, false = walkable path.
    maze = List.generate(
      size,
      (_) => List<bool>.filled(size, true),
    );

    player = const Point<int>(1, 1);
    goal = Point<int>(size - 2, size - 2);

    final List<Point<int>> stack = [player];
    maze[player.y][player.x] = false;

    // Randomized depth-first search creates a connected maze.
    while (stack.isNotEmpty) {
      final current = stack.last;

      final directions = <Point<int>>[
        const Point<int>(0, -1),
        const Point<int>(0, 1),
        const Point<int>(-1, 0),
        const Point<int>(1, 0),
      ]..shuffle(_random);

      Point<int>? next;
      Point<int>? direction;

      for (final dir in directions) {
        final nx = current.x + dir.x * 2;
        final ny = current.y + dir.y * 2;

        if (nx < 1 ||
            ny < 1 ||
            nx >= size - 1 ||
            ny >= size - 1) {
          continue;
        }

        if (maze[ny][nx]) {
          next = Point<int>(nx, ny);
          direction = dir;
          break;
        }
      }

      if (next == null || direction == null) {
        stack.removeLast();
        continue;
      }

      // Open the wall between the current cell and next cell.
      final wallX = current.x + direction.x;
      final wallY = current.y + direction.y;

      maze[wallY][wallX] = false;
      maze[next.y][next.x] = false;

      stack.add(next);
    }

    // The algorithm guarantees a path between start and finish.
  }

  // ------------------------------------------------------------
  // SOUND
  // ------------------------------------------------------------

  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('sounds/$fileName'),
      );
    } catch (e) {
      debugPrint('Could not play $fileName: $e');
    }
  }

  // ------------------------------------------------------------
  // TIMER
  // ------------------------------------------------------------

  void _startRoundTimer({bool resetTime = true}) {
    roundTimer?.cancel();

    if (gameOver || isPaused) return;

    if (resetTime) {
      secondsRemaining = roundTimeLimit;
    }

    roundTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || gameOver || isPaused) {
          timer.cancel();
          return;
        }

        if (secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            secondsRemaining = 0;
          });

          _handleTimeout();
        } else {
          setState(() {
            secondsRemaining--;
          });
        }
      },
    );
  }

  void _handleTimeout() {
    if (gameOver || isPaused) return;

    _playSound('timeout.mp3');

    final bool noLivesLeft = lives <= 1;

    setState(() {
      lives--;

      feedbackText = noLivesLeft
          ? 'Out of time and out of lives!'
          : 'Time is up! Try this maze again.';

      feedbackColor = Colors.redAccent;

      if (!noLivesLeft) {
        _generateMaze();
        secondsRemaining = roundTimeLimit;
      }
    });

    if (noLivesLeft) {
      _finishGame(completedAll: false);
    } else {
      _startRoundTimer(resetTime: false);
    }
  }

  // ------------------------------------------------------------
  // SWIPE MOVEMENT
  // ------------------------------------------------------------

  void _handleSwipe(DragEndDetails details) {
    if (isPaused || gameOver) return;

    final velocity = details.velocity.pixelsPerSecond;

    if (velocity.dx.abs() < 100 &&
        velocity.dy.abs() < 100) {
      return;
    }

    if (velocity.dx.abs() > velocity.dy.abs()) {
      // Horizontal swipe.
      _movePlayer(
        rowDelta: 0,
        colDelta: velocity.dx > 0 ? 1 : -1,
      );
    } else {
      // Vertical swipe.
      _movePlayer(
        rowDelta: velocity.dy > 0 ? 1 : -1,
        colDelta: 0,
      );
    }
  }

  void _movePlayer({
    required int rowDelta,
    required int colDelta,
  }) {
    if (isPaused || gameOver) return;

    final int nextRow = player.y + rowDelta;
    final int nextCol = player.x + colDelta;

    if (nextRow < 0 ||
        nextCol < 0 ||
        nextRow >= mazeSize ||
        nextCol >= mazeSize ||
        maze[nextRow][nextCol]) {
      setState(() {
        wallBumps++;
        feedbackText = 'Blocked! Find another route.';
        feedbackColor = Colors.orangeAccent;
      });
      return;
    }

    final nextPosition = Point<int>(nextCol, nextRow);

    if (nextPosition.x == goal.x &&
        nextPosition.y == goal.y) {
      _completeRound();
      return;
    }

    setState(() {
      player = nextPosition;
      moves++;

      feedbackText = 'Keep going!';
      feedbackColor = Colors.white;
    });
  }

  // ------------------------------------------------------------
  // ROUND COMPLETION
  // ------------------------------------------------------------

  void _completeRound() {
    roundTimer?.cancel();

    final int bonus = secondsRemaining >= roundTimeLimit ~/ 2
        ? 5
        : 0;

    setState(() {
      roundsCompleted++;
      moves++;

      xp += 20 + bonus;

      if (bestRoundTime == 0 ||
          secondsRemaining > bestRoundTime) {
        bestRoundTime = secondsRemaining;
      }

      feedbackText = bonus > 0
          ? 'Exit found! +${20 + bonus} XP'
          : 'Exit found! +20 XP';

      feedbackColor = const Color(0xFF38EF7D);
    });

    _playSound('correct.mp3');

    if (roundsCompleted >= maxRounds) {
      _finishGame(completedAll: true);
      return;
    }

    setState(() {
      _generateMaze();
      secondsRemaining = roundTimeLimit;
    });

    _startRoundTimer(resetTime: false);
  }

  // ------------------------------------------------------------
  // PAUSE / RESUME
  // ------------------------------------------------------------

  void pauseGame() {
    if (gameOver || isPaused) return;

    roundTimer?.cancel();

    setState(() {
      isPaused = true;
    });

    _audioPlayer.pause();
  }

  void resumeGame() {
    if (!isPaused || gameOver) return;

    setState(() {
      isPaused = false;
    });

    _audioPlayer.resume();
    _startRoundTimer(resetTime: false);
  }

  // ------------------------------------------------------------
  // FINISH / SAVE SCORE
  // ------------------------------------------------------------

  void _finishGame({required bool completedAll}) {
    if (gameOver) return;

    roundTimer?.cancel();

    setState(() {
      gameOver = true;
      isPaused = false;
    });

    if (completedAll) {
      _playSound('level_complete.mp3');
      confettiController.play();
    } else {
      _playSound('wrong.mp3');
    }

    _saveScore();
  }

  Future<void> _saveScore() async {
    if (_scoreSaved) return;
    _scoreSaved = true;

    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 8,
        'levelName': 'Path Finder',
        'completed': roundsCompleted >= maxRounds,
        'roundsCompleted': roundsCompleted,
        'totalRounds': maxRounds,
        'moves': moves,
        'wallBumps': wallBumps,
        'livesRemaining': lives,
        'xp': xp,
        'accuracy': accuracy,
        'grade': getGrade(),
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Failed to save Path Finder score: $e');
    }
  }

  // ------------------------------------------------------------
  // RESTART
  // ------------------------------------------------------------

  void restartGame() {
    roundTimer?.cancel();
    _scoreSaved = false;

    setState(() {
      roundsCompleted = 0;
      secondsRemaining = 38;
      lives = startingLives;
      moves = 0;
      wallBumps = 0;
      xp = 0;
      bestRoundTime = 0;

      isPaused = false;
      gameOver = false;

      feedbackText = 'Swipe to find the exit!';
      feedbackColor = Colors.white;

      _generateMaze();
      secondsRemaining = roundTimeLimit;
    });

    confettiController.stop();
    _startRoundTimer(resetTime: false);
  }

  @override
  void dispose() {
    roundTimer?.cancel();
    confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // MAIN BUILD
  // ------------------------------------------------------------

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF160B36),
              Color(0xFF39216C),
              Color(0xFF170B3D),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                // YOUR EXISTING GAME SCREEN
                Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    _buildHud(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: gameOver
                          ? _buildResults()
                          : _buildGameplay(),
                    ),
                  ],
                ),

                // PAUSE MENU OVERLAY
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
      ),
    );
  }


  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF64E7FF),
                width: 1.5,
              ),
            ),
            child: const Text(
              'LEVEL 8: PATH FINDER',
              style: TextStyle(
                color: Color(0xFF64E7FF),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          if (!gameOver && !isPaused)
            IconButton(
              onPressed: pauseGame,
              tooltip: 'Pause game',
              icon: const Icon(
                Icons.pause_circle_filled_rounded,
                color: Colors.white,
                size: 34,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // HUD
  // ------------------------------------------------------------

  Widget _buildHud() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _hudItem('⭐ XP', '$xp', Colors.amber),
          _hudItem('👣 MOVES', '$moves', Colors.cyanAccent),
          _hudItem(
            '❤️ LIVES',
            '$lives',
            Colors.pinkAccent,
          ),
        ],
      ),
    );
  }

  Widget _hudItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // GAMEPLAY
  // ------------------------------------------------------------

  Widget _buildGameplay() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROUND $currentRound / $maxRounds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: secondsRemaining <= 8
                      ? Colors.red.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: secondsRemaining <= 8
                        ? Colors.redAccent
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      color: secondsRemaining <= 8
                          ? Colors.redAccent
                          : const Color(0xFFFFD700),
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${secondsRemaining}s',
                      style: TextStyle(
                        color: secondsRemaining <= 8
                            ? Colors.redAccent
                            : const Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Text(
          'START  →  FIND THE EXIT',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),

        const SizedBox(height: 6),

        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanEnd: _handleSwipe,
                  child: Container(
                    width: boardSize,
                    height: boardSize,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF08051A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF64E7FF),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: GridView.builder(
                      physics:
                          const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: mazeSize * mazeSize,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: mazeSize,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      itemBuilder: (context, index) {
                        final row = index ~/ mazeSize;
                        final col = index % mazeSize;

                        final isPlayer =
                            player.x == col && player.y == row;

                        final isGoal =
                            goal.x == col && goal.y == row;

                        final isStart = row == 1 && col == 1;
                        final isWall = maze[row][col];

                        Color tileColor;

                        if (isPlayer) {
                          tileColor = const Color(0xFF38EF7D);
                        } else if (isGoal) {
                          tileColor = const Color(0xFFFFD700);
                        } else if (isWall) {
                          tileColor = const Color(0xFF241C42);
                        } else if (isStart) {
                          tileColor = const Color(0xFF315C9D);
                        } else {
                          tileColor = const Color(0xFFB6A8E8);
                        }

                        final double iconSize =
                            max(7.0, boardSize / mazeSize * 0.72);

                        return Container(
                          color: tileColor,
                          alignment: Alignment.center,
                          child: isPlayer
                              ? Icon(
                                  Icons.directions_run_rounded,
                                  size: iconSize,
                                  color: const Color(0xFF073B20),
                                )
                              : isGoal
                                  ? Icon(
                                      Icons.flag_rounded,
                                      size: iconSize,
                                      color: const Color(0xFF563900),
                                    )
                                  : isStart
                                      ? Icon(
                                          Icons.play_arrow_rounded,
                                          size: iconSize,
                                          color: Colors.white,
                                        )
                                      : null,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          feedbackText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: feedbackColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 5),

        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'SWIPE UP, DOWN, LEFT OR RIGHT TO MOVE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // RESULTS
  // ------------------------------------------------------------

  Widget _buildResults() {
    final bool completedAll = roundsCompleted >= maxRounds;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 18,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                completedAll
                    ? '🏆 PATH MASTER!'
                    : '🧩 KEEP EXPLORING!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                completedAll
                    ? 'You found every exit!'
                    : 'You completed $roundsCompleted of $maxRounds mazes.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 22),

              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    getGrade(),
                    style: const TextStyle(
                      color: Color(0xFF39216C),
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    _resultRow('Mazes completed', '$roundsCompleted / $maxRounds'),
                    const Divider(color: Colors.white12),
                    _resultRow('XP earned', '$xp ⭐'),
                    const Divider(color: Colors.white12),
                    _resultRow('Total moves', '$moves'),
                    const Divider(color: Colors.white12),
                    _resultRow('Wall bumps', '$wallBumps'),
                    const Divider(color: Colors.white12),
                    _resultRow('Accuracy', '${accuracy.toStringAsFixed(0)}%'),
                    const Divider(color: Colors.white12),
                    _resultRow('Grade', getGrade()),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _GameButton(
                text: 'PLAY AGAIN',
                color: const Color(0xFFFF8008),
                onPressed: restartGame,
              ),

              const SizedBox(height: 12),

              _GameButton(
                text: 'LEVEL SELECT',
                color: const Color(0xFF38EF7D),
                textColor: const Color(0xFF073B20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFFD700),
              Color(0xFF38EF7D),
              Color(0xFF64E7FF),
              Colors.pink,
              Colors.purple,
            ],
          ),
        ),
      ],
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------
// REUSABLE BUTTON
// --------------------------------------------------------------

class _GameButton extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _GameButton({
    required this.text,
    required this.color,
    this.textColor = Colors.white,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Colors.white70,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
