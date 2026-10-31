import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_difficulty.dart';
import 'memory_match.dart';
import '../services/game_audio.dart';
import '../services/game_options_menu.dart';
import '../widgets/pause_menu.dart';

class SciencePuzzle extends StatefulWidget {
  final GameDifficulty difficulty;

  const SciencePuzzle({super.key, this.difficulty = GameDifficulty.hard});

  @override
  State<SciencePuzzle> createState() => _SciencePuzzleState();
}

class _SciencePuzzleState extends State<SciencePuzzle>
    with TickerProviderStateMixin {
  // ============================================================
  // PUZZLE SETTINGS
  // ============================================================

  int get puzzleSize => widget.difficulty == GameDifficulty.hard ? 4 : 3;
  int get totalPieces => puzzleSize * puzzleSize;
  int get memoryDuration => widget.difficulty == GameDifficulty.easy ? 10 : 5;
  int get totalGameDuration {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 0;
      case GameDifficulty.medium:
        return 60;
      case GameDifficulty.hard:
        return 45;
    }
  }

  bool get hasGameTimer => widget.difficulty != GameDifficulty.easy;

  final List<String> puzzleImages = [
    'assets/images/science/volcano.png',
    'assets/images/science/human_body.png',
    'assets/images/science/solar_system.png',
  ];

  late String selectedImage;

  List<int> solved = [];
  List<int> pieces = [];
  int? selectedPieceIndex;
  int moves = 0;
  int memorySeconds = 0;
  int gameSeconds = 0;

  bool memorizing = true;
  bool completed = false;
  bool gameEnded = false;
  bool isPaused = false;
  bool showOptions = false;

  int xp = 0;
  int score = 0;
  int streakCount = 0;

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

    confetti = ConfettiController(duration: const Duration(seconds: 2));

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _initAudio();
    startNewGame();
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
  // GAME FLOW
  // ============================================================

  void startNewGame() {
    timer?.cancel();
    final random = Random();

    selectedImage = puzzleImages[random.nextInt(puzzleImages.length)];
    solved = List.generate(totalPieces, (index) => index);
    pieces = List.from(solved);
    selectedPieceIndex = null;
    moves = 0;
    memorySeconds = memoryDuration;
    gameSeconds = totalGameDuration;

    memorizing = true;
    completed = false;
    gameEnded = false;
    isPaused = false;
    showOptions = false;
    xp = 0;
    score = 0;

    startMemory();
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
    if (memorizing) {
      startMemory();
    } else if (hasGameTimer) {
      startGameTimer();
    }
  }

  void startMemory() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (isPaused) return;
      setState(() => memorySeconds--);
      if (memorySeconds <= 0) {
        t.cancel();
        scramble();
      }
    });
  }

  void scramble() {
    do {
      pieces.shuffle(Random());
    } while (_isSolved());

    setState(() {
      memorizing = false;
    });

    if (hasGameTimer) startGameTimer();
  }

  void startGameTimer() {
    timer?.cancel();
    if (!hasGameTimer) return;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (isPaused) return;
      setState(() => gameSeconds--);
      if (gameSeconds <= 0) {
        t.cancel();
        _shakeController.forward(from: 0.0);
        audio.playWrong();
        endGame(false);
      }
    });
  }

  void movePiece(int index) {
    if (completed || gameEnded || memorizing || isPaused) return;

    setState(() {
      if (selectedPieceIndex == null) {
        selectedPieceIndex = index;
        audio.playSfx('pop.mp3');
        return;
      }

      if (selectedPieceIndex == index) {
        selectedPieceIndex = null;
        return;
      }

      final temp = pieces[selectedPieceIndex!];
      pieces[selectedPieceIndex!] = pieces[index];
      pieces[index] = temp;
      moves++;
      selectedPieceIndex = null;
      audio.playSfx('click.mp3');
    });

    checkSolved();
  }

  bool _isSolved() {
    for (int i = 0; i < pieces.length; i++) {
      if (pieces[i] != solved[i]) return false;
    }
    return true;
  }

  void checkSolved() {
    if (_isSolved()) endGame(true);
  }

  void calculateResults() {
    final int timeUsed = hasGameTimer ? totalGameDuration - gameSeconds : 0;
    int calculatedScore = 1000;
    calculatedScore -= moves * 10;
    if (hasGameTimer) calculatedScore -= timeUsed * 5;
    if (calculatedScore < 0) calculatedScore = 0;
    score = calculatedScore;

    xp = 20;
    if (moves <= 15) xp += 10;
    if (hasGameTimer && timeUsed <= 30) xp += 10;
  }

  String getGrade() {
    if (score >= 900) return 'S';
    if (score >= 750) return 'A';
    if (score >= 600) return 'B';
    if (score >= 450) return 'C';
    return 'D';
  }

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

    setState(() => completed = true);
    saveScore(win);
  }

  Future<void> saveScore(bool win) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      String? guestId = prefs.getString('guest_player_id');

      if (user == null && (guestId == null || guestId.isEmpty)) {
        guestId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
        await prefs.setString('guest_player_id', guestId);
      }

      final savedName = prefs.getString('player_username')?.trim();
      final displayName = user?.displayName?.trim();
      final String playerName =
          savedName != null && savedName.isNotEmpty
              ? savedName
              : displayName != null && displayName.isNotEmpty
                  ? displayName
                  : 'Guest Player';

      await FirebaseFirestore.instance.collection('scores').add({
        'playerId': user?.uid ?? guestId,
        'playerName': playerName,
        'level': 2,
        'levelName': 'Science Puzzle',
        'difficulty': widget.difficulty.label,
        'image': selectedImage,
        'moves': moves,
        'score': score,
        'xp': xp,
        'grade': win ? getGrade() : 'F',
        'completed': win,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('Science Puzzle score saved successfully.');
    } catch (e) {
      debugPrint('Error saving Science Puzzle score: $e');
    }
  }

  void goToMainMenu() => Navigator.pop(context);

  // NEXT LEVEL → Memory Match (same difficulty)
  void goToNextLevel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryMatch(
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
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

  Widget _buildCustomAppBar() {
    return SafeArea(
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
                'Science Puzzle',
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

  Widget buildPuzzlePiece(int index) {
    final pieceNumber = pieces[index];
    final row = pieceNumber ~/ puzzleSize;
    final column = pieceNumber % puzzleSize;
    final isSelected = selectedPieceIndex == index;

    return GestureDetector(
      onTap: () => movePiece(index),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pieceWidth = constraints.maxWidth;
          final pieceHeight = constraints.maxHeight;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.amber : Colors.white24,
                width: isSelected ? 3.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Positioned(
                    left: -column * pieceWidth,
                    top: -row * pieceHeight,
                    width: pieceWidth * puzzleSize,
                    height: pieceHeight * puzzleSize,
                    child: Image.asset(selectedImage, fit: BoxFit.fill),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildResultScreen() {
    final bool passed = xp > 0;
    final int timeUsed = hasGameTimer ? totalGameDuration - gameSeconds : 0;

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
                    passed ? '🎉 LEVEL COMPLETE!' : '⏰ TIME IS UP!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: passed ? Colors.amber : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    passed
                        ? 'Great job! You assembled the puzzle.'
                        : 'You ran out of time! Try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  if (passed) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      _buildStatBadge('⭐ XP', passed ? '+$xp' : '0'),
                      _buildStatBadge('🧩 Moves', '$moves'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (hasGameTimer)
                    Text(
                      '⏱ Time Used: ${timeUsed}s',
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
                  if (passed) ...[
                    const SizedBox(height: 10),
                    _buildChunkyButton(
                      label: 'Next Level',
                      icon: Icons.arrow_forward_rounded,
                      color: const Color(0xFFFFD700),
                      onPressed: goToNextLevel,
                    ),
                  ],
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

  Widget _buildStatBadge(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 13)),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Row(
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
    );
  }

  Widget _buildGameplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (memorizing || hasGameTimer)
                _buildHudCard(
                  icon: Icons.timer_outlined,
                  title: 'TIME',
                  value: memorizing ? '${memorySeconds}s' : '${gameSeconds}s',
                  valueColor: memorizing ? Colors.amber : Colors.cyanAccent,
                ),
              _buildHudCard(
                icon: Icons.grid_view_rounded,
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
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, area) {
                final maxPuzzleSize = min(
                  min(area.maxWidth * 0.98, area.maxHeight * 0.98),
                  410.0,
                );
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        memorizing ? 'MEMORIZE THE IMAGE' : 'SOLVE THE PUZZLE',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: memorizing ? Colors.amber : Colors.cyanAccent,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: maxPuzzleSize,
                        height: maxPuzzleSize,
                        child: memorizing ? _buildMemoryImage() : _buildPuzzleGrid(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        memorizing
                            ? 'Study the image carefully!'
                            : 'Tap two pieces to swap them',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(selectedImage, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildPuzzleGrid() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: puzzleSize,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: totalPieces,
        itemBuilder: (context, index) => buildPuzzlePiece(index),
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
            colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)],
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
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    ),
                    child: completed ? buildResultScreen() : _buildGameplay(),
                  ),
                ),
              ],
            ),
            if (isPaused)
              Positioned.fill(
                child: showOptions
                    ? GameOptionsMenu(
                        audio: audio,
                        onBack: () => setState(() => showOptions = false),
                      )
                    : PauseMenu(
                        onResume: resumeGame,
                        onRestart: restartGame,
                        onOptions: () => setState(() => showOptions = true),
                        onMainMenu: goToMainMenu,
                      ),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confetti,
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

  @override
  void dispose() {
    timer?.cancel();
    confetti.dispose();
    audio.dispose();
    _shakeController.dispose();
    super.dispose();
  }
}