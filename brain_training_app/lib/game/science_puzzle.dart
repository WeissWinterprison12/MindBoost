import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'memory_match.dart';
import '../widgets/pause_menu.dart';

class SciencePuzzle extends StatefulWidget {
  const SciencePuzzle({super.key});

  @override
  State<SciencePuzzle> createState() => _SciencePuzzleState();
}

class _SciencePuzzleState extends State<SciencePuzzle>
    with TickerProviderStateMixin {
  // ============================================================
  // PUZZLE SETTINGS
  // ============================================================

  static const int puzzleSize = 3;
  static const int totalPieces = puzzleSize * puzzleSize;

  static const int memoryDuration = 5;
  static const int totalGameDuration = 60;

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

  int memorySeconds = memoryDuration;
  int gameSeconds = totalGameDuration;

  bool memorizing = true;
  bool completed = false;
  bool gameEnded = false;
  bool isPaused = false;
  bool showOptions = false;

  // Match MathGame: both audio settings start at 50%.
  double musicVolume = 0.5;
  double soundVolume = 0.5;
  bool _musicStoppedForMute = false;

  int xp = 0;
  int score = 0;
  int streakCount = 0;

  Timer? timer;

  late ConfettiController confetti;

  // Separate players let the background music continue while effects play.
  final AudioPlayer player = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    confetti = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    )
        .chain(
          CurveTween(
            curve: Curves.elasticIn,
          ),
        )
        .animate(_shakeController);

    _initAudio();
    startNewGame();
  }

  // ============================================================
  // AUDIO
  // ============================================================

  Future<void> _initAudio() async {
    await _configureAudio();
    await _startBackgroundMusic();
  }

  Future<void> _configureAudio() async {
    final AudioContext audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
      ),
    );

    try {
      await _musicPlayer.setAudioContext(audioContext);
      await player.setAudioContext(audioContext);
      await player.setVolume(soundVolume);
    } catch (error) {
      debugPrint('Could not configure audio mixing: $error');
    }
  }

  Future<void> _startBackgroundMusic() async {
    if (musicVolume <= 0.0) {
      _musicStoppedForMute = true;
      try {
        await _musicPlayer.stop();
      } catch (error) {
        debugPrint('Could not stop muted music: $error');
      }
      return;
    }

    if (!mounted || isPaused || completed || gameEnded) return;

    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(musicVolume);
      await _musicPlayer.play(
        AssetSource('sounds/The_Measured_Proof.mp3'),
        volume: musicVolume,
      );
      _musicStoppedForMute = false;
    } catch (error) {
      debugPrint('Could not play background music: $error');
    }
  }

  Future<void> _playSound(String assetName) async {
    if (soundVolume <= 0.0) return;

    try {
      await player.stop();
      await player.setVolume(soundVolume);
      await player.play(
        AssetSource(assetName),
        volume: soundVolume,
      );
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  Future<void> changeMusicVolume(double value) async {
    final double volume = value.clamp(0.0, 1.0).toDouble();
    if (!mounted) return;

    setState(() => musicVolume = volume);

    try {
      if (volume <= 0.0) {
        _musicStoppedForMute = true;
        await _musicPlayer.stop();
      } else if (_musicStoppedForMute) {
        if (!isPaused && !completed && !gameEnded) {
          await _startBackgroundMusic();
        }
      } else {
        await _musicPlayer.setVolume(volume);
      }
    } catch (error) {
      debugPrint('Could not change music volume: $error');
    }
  }

  Future<void> changeSoundVolume(double value) async {
    final double volume = value.clamp(0.0, 1.0).toDouble();
    if (!mounted) return;

    setState(() => soundVolume = volume);

    try {
      await player.setVolume(volume);
    } catch (error) {
      debugPrint('Could not change sound volume: $error');
    }
  }

  void showGameOptions() {
    if (!mounted) return;
    setState(() => showOptions = true);
  }

  // ============================================================
  // START / RESTART
  // ============================================================

  void startNewGame() {
    timer?.cancel();

    final random = Random();

    selectedImage =
        puzzleImages[random.nextInt(puzzleImages.length)];

    solved = List.generate(
      totalPieces,
      (index) => index,
    );

    pieces = List.from(solved);

    selectedPieceIndex = null;

    moves = 0;

    memorySeconds = memoryDuration;
    gameSeconds = totalGameDuration;

    memorizing = true;
    completed = false;
    gameEnded = false;
    isPaused = false;

    xp = 0;
    score = 0;

    startMemory();
  }

  void restartGame() {
    timer?.cancel();

    setState(() {
      startNewGame();
    });

    _startBackgroundMusic();
  }

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  void pauseGame() {
    if (completed || gameEnded || isPaused) return;

    timer?.cancel();

    player.pause();
    _musicPlayer.pause();

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

    if (musicVolume <= 0.0) {
      _musicStoppedForMute = true;
      await _musicPlayer.stop();
    } else if (_musicStoppedForMute) {
      await _startBackgroundMusic();
    } else {
      await _musicPlayer.setVolume(musicVolume);
      await _musicPlayer.resume();
    }

    await player.setVolume(soundVolume);
    await player.resume();

    if (memorizing) {
      startMemory();
    } else {
      startGameTimer();
    }
  }

  // ============================================================
  // MEMORY PHASE
  // ============================================================

  void startMemory() {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        if (isPaused) return;

        setState(() {
          memorySeconds--;
        });

        if (memorySeconds <= 0) {
          t.cancel();
          scramble();
        }
      },
    );
  }

  // ============================================================
  // SCRAMBLE PUZZLE
  // ============================================================

  void scramble() {
    do {
      pieces.shuffle(Random());
    } while (_isSolved());

    setState(() {
      memorizing = false;
    });

    startGameTimer();
  }

  // ============================================================
  // GAME TIMER
  // ============================================================

  void startGameTimer() {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
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

          _shakeController.forward(
            from: 0.0,
          );

          _playSound(
            'sounds/wrong.mp3',
          );

          endGame(false);
        }
      },
    );
  }

  // ============================================================
  // SELECT / SWAP PIECES
  // ============================================================

  void movePiece(int index) {
    if (completed ||
        gameEnded ||
        memorizing ||
        isPaused) {
      return;
    }

    setState(() {
      // First selection.
      if (selectedPieceIndex == null) {
        selectedPieceIndex = index;

        _playSound(
          'sounds/pop.mp3',
        );

        return;
      }

      // Same piece = deselect.
      if (selectedPieceIndex == index) {
        selectedPieceIndex = null;
        return;
      }

      // Swap pieces.
      final temp =
          pieces[selectedPieceIndex!];

      pieces[selectedPieceIndex!] =
          pieces[index];

      pieces[index] = temp;

      moves++;

      selectedPieceIndex = null;

      _playSound(
        'sounds/click.mp3',
      );
    });

    checkSolved();
  }

  // ============================================================
  // CHECK SOLVED
  // ============================================================

  bool _isSolved() {
    for (int i = 0; i < pieces.length; i++) {
      if (pieces[i] != solved[i]) {
        return false;
      }
    }

    return true;
  }

  void checkSolved() {
    if (_isSolved()) {
      endGame(true);
    }
  }

  // ============================================================
  // SCORE
  // ============================================================

  void calculateResults() {
    final int timeUsed =
        totalGameDuration - gameSeconds;

    int calculatedScore = 1000;

    // Move penalty.
    calculatedScore -= moves * 10;

    // Time penalty.
    calculatedScore -= timeUsed * 5;

    if (calculatedScore < 0) {
      calculatedScore = 0;
    }

    score = calculatedScore;

    // Base XP.
    xp = 20;

    // Efficient solving bonus.
    if (moves <= 15) {
      xp += 10;
    }

    // Fast completion bonus.
    if (timeUsed <= 30) {
      xp += 10;
    }
  }

  // ============================================================
  // GRADE
  // ============================================================

  String getGrade() {
    if (score >= 900) return 'S';
    if (score >= 750) return 'A';
    if (score >= 600) return 'B';
    if (score >= 450) return 'C';

    return 'D';
  }

  // ============================================================
  // END GAME
  // ============================================================

  void endGame(bool win) {
    if (gameEnded) return;

    gameEnded = true;

    timer?.cancel();

    _musicPlayer.stop();

    if (win) {
      calculateResults();

      streakCount++;

      confetti.play();

      _playSound(
        'sounds/level up.mp3',
      );
    } else {
      xp = 0;
      score = 0;
      streakCount = 0;
    }

    setState(() {
      completed = true;
    });

    saveScore(win);
  }

  // ============================================================
  // FIREBASE
  // ============================================================

  Future<void> saveScore(bool win) async {
    try {
      await FirebaseFirestore.instance
          .collection('scores')
          .add({
        'level': 'Science Puzzle',
        'image': selectedImage,
        'moves': moves,
        'score': score,
        'xp': xp,
        'grade': win ? getGrade() : 'F',
        'completed': win,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint(
        'Error saving score: $e',
      );
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void goToMainMenu() {
    Navigator.pop(context);
  }

  void goToNextLevel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const MemoryMatch(),
      ),
    );
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
          borderRadius:
              BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: 0.4,
              ),
              offset:
                  const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
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
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
              child: const Text(
                'Science Puzzle',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
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
  // PUZZLE PIECE
  // ============================================================

  Widget buildPuzzlePiece(int index) {
    final pieceNumber =
        pieces[index];

    final row =
        pieceNumber ~/ puzzleSize;

    final column =
        pieceNumber % puzzleSize;

    final isSelected =
        selectedPieceIndex == index;

    return GestureDetector(
      onTap: () {
        movePiece(index);
      },
      child: LayoutBuilder(
        builder:
            (context, constraints) {
          final pieceWidth =
              constraints.maxWidth;

          final pieceHeight =
              constraints.maxHeight;

          return AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 200,
            ),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              border: Border.all(
                color: isSelected
                    ? Colors.amber
                    : Colors.white24,
                width:
                    isSelected ? 3.5 : 1,
              ),
              boxShadow:
                  isSelected
                      ? [
                          BoxShadow(
                            color:
                                Colors.amber
                                    .withValues(
                              alpha: 0.6,
                            ),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                6,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left:
                        -column *
                            pieceWidth,
                    top:
                        -row *
                            pieceHeight,
                    width:
                        pieceWidth *
                            puzzleSize,
                    height:
                        pieceHeight *
                            puzzleSize,
                    child:
                        Image.asset(
                      selectedImage,
                      fit: BoxFit.fill,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // RESULT SCREEN
  // ============================================================

  Widget buildResultScreen() {
    final bool passed = xp > 0;

    final int timeUsed =
        totalGameDuration -
            gameSeconds;

    return Center(
      child: SingleChildScrollView(
        physics:
            const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10,
              sigmaY: 10,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    passed
                        ? '🎉 LEVEL COMPLETE!'
                        : '⏰ TIME IS UP!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w900,
                      color: passed
                          ? Colors.amber
                          : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign:
                        TextAlign.center,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    passed
                        ? 'Great job! You assembled the puzzle.'
                        : 'You ran out of time! Try again.',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontSize: 14,
                      color:
                          Colors.white70,
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  if (passed) ...[
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.amber
                            .withValues(
                          alpha: 0.2,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        border:
                            Border.all(
                          color:
                              Colors.amber,
                        ),
                      ),
                      child: Text(
                        'GRADE: ${getGrade()}',
                        style:
                            const TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.w900,
                          color:
                              Colors.amber,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),
                  ],

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceEvenly,
                    children: [
                      _buildStatBadge(
                        '🏆 Score',
                        '$score',
                      ),
                      _buildStatBadge(
                        '⭐ XP',
                        passed
                            ? '+$xp'
                            : '0',
                      ),
                      _buildStatBadge(
                        '🧩 Moves',
                        '$moves',
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    '⏱ Time Used: ${timeUsed}s',
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  if (passed) ...[
                    _buildChunkyButton(
                      label:
                          'Next Level',
                      icon: Icons
                          .arrow_forward_rounded,
                      color:
                          const Color(
                        0xFFFF9F1C,
                      ),
                      onPressed:
                          goToNextLevel,
                    ),

                    const SizedBox(
                      height: 10,
                    ),
                  ],

                  _buildChunkyButton(
                    label: 'Try Again',
                    icon: Icons
                        .refresh_rounded,
                    color:
                        const Color(
                      0xFF2EC4B6,
                    ),
                    onPressed:
                        restartGame,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  _buildChunkyButton(
                    label: 'Main Menu',
                    icon:
                        Icons.home_rounded,
                    color:
                        Colors.white24,
                    onPressed:
                        goToMainMenu,
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
  // STAT BADGE
  // ============================================================

  Widget _buildStatBadge(
    String title,
    String value,
  ) {
    return Column(
      children: [
        Text(
          title,
          style:
              const TextStyle(
            color: Colors.white60,
            fontSize: 13,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          value,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
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
      borderRadius:
          BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8,
          sigmaY: 8,
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration:
              BoxDecoration(
            color:
                Colors.white.withValues(
              alpha: 0.1,
            ),
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color:
                  Colors.white.withValues(
                alpha: 0.18,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color:
                        Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  Text(
                    title,
                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GAMEPLAY CONTENT
  // ============================================================

  Widget _buildGameplay() {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        return Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Column(
            children: [
              // -----------------------------
              // HUD
              // -----------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly,
                children: [
                  _buildHudCard(
                    icon:
                        Icons.timer_outlined,
                    title: 'TIME',
                    value: memorizing
                        ? '${memorySeconds}s'
                        : '${gameSeconds}s',
                    valueColor: memorizing
                        ? Colors.amber
                        : Colors.cyanAccent,
                  ),
                  _buildHudCard(
                    icon:
                        Icons.grid_view_rounded,
                    title: 'MOVES',
                    value: '$moves',
                    valueColor:
                        Colors.purpleAccent,
                  ),
                  _buildHudCard(
                    icon: Icons
                        .local_fire_department,
                    title: 'STREAK',
                    value:
                        '$streakCount',
                    valueColor:
                        Colors.orangeAccent,
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              // -----------------------------
              // MAIN PUZZLE AREA
              // -----------------------------

              Expanded(
                child: LayoutBuilder(
                  builder:
                      (context, area) {
                    final availableWidth =
                        area.maxWidth;

                    final availableHeight =
                        area.maxHeight;

                    final maxPuzzleSize = min(
                      availableWidth * 0.98,
                      availableHeight * 0.98,
                    );

                    final puzzleSizeValue = min(
                      maxPuzzleSize,
                      410.0,
                    );

                    return Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Text(
                            memorizing
                                ? 'MEMORIZE THE IMAGE'
                                : 'SOLVE THE PUZZLE',
                            style:
                                TextStyle(
                              fontSize:
                                  memorizing
                                      ? 20
                                      : 20,
                              fontWeight:
                                  FontWeight.w900,
                              color: memorizing
                                  ? Colors
                                      .amber
                                  : Colors
                                      .cyanAccent,
                              letterSpacing:
                                  1.2,
                            ),
                            textAlign:
                                TextAlign.center,
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          SizedBox(
                            width:
                                puzzleSizeValue,
                            height:
                                puzzleSizeValue,
                            child:
                                memorizing
                                    ? _buildMemoryImage()
                                    : _buildPuzzleGrid(),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            memorizing
                                ? 'Study the image carefully!'
                                : 'Tap two pieces to swap them',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white60,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                            textAlign:
                                TextAlign.center,
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
      },
    );
  }

  // ============================================================
  // MEMORY IMAGE
  // ============================================================

  Widget _buildMemoryImage() {
    return Container(
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white30,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(18),
        child: Image.asset(
          selectedImage,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ============================================================
  // PUZZLE GRID
  // ============================================================

  Widget _buildPuzzleGrid() {
    return Container(
      padding:
          const EdgeInsets.all(8),
      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white24,
        ),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics:
            const NeverScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: puzzleSize,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: totalPieces,
        itemBuilder:
            (context, index) {
          return buildPuzzlePiece(
            index,
          );
        },
      ),
    );
  }

  // ============================================================
  // OPTIONS SCREEN (matches MathGame)
  // ============================================================

  Widget _buildOptionsScreen() {
    return Material(
      color: Colors.transparent,
      child: Container(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B0B46).withOpacity(0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '⚙️ OPTIONS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Adjust your game audio',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildOptionsVolumeSlider(
                        title: '🎵 Background Music',
                        value: musicVolume,
                        onChanged: changeMusicVolume,
                      ),
                      const SizedBox(height: 22),
                      _buildOptionsVolumeSlider(
                        title: '🔊 Sound Effects',
                        value: soundVolume,
                        onChanged: changeSoundVolume,
                      ),
                      const SizedBox(height: 30),
                      _buildChunkyButton(
                        label: '← Back',
                        icon: Icons.arrow_back_rounded,
                        color: const Color(0xFFFFD700),
                        onPressed: () {
                          setState(() => showOptions = false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsVolumeSlider({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final int percentage = (value * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.65),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFFD700),
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFFFFD700).withOpacity(0.18),
              trackHeight: 6,
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '$percentage%',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(
          gradient:
              LinearGradient(
            colors: [
              Color(0xFF4A0E4E),
              Color(0xFF811252),
              Color(0xFF2E0854),
            ],
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildCustomAppBar(),

                Expanded(
                  child: AnimatedBuilder(
                    animation:
                        _shakeAnimation,
                    builder:
                        (context, child) {
                      return Transform
                          .translate(
                        offset: Offset(
                          _shakeAnimation
                              .value,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: completed
                        ? buildResultScreen()
                        : _buildGameplay(),
                  ),
                ),
              ],
            ),

            // ==================================================
            // PAUSE MENU
            // ==================================================

            if (isPaused)
              Positioned.fill(
                child: showOptions
                    ? _buildOptionsScreen()
                    : PauseMenu(
                        onResume: resumeGame,
                        onRestart: restartGame,
                        onOptions: showGameOptions,
                        onMainMenu: goToMainMenu,
                      ),
              ),

            // ==================================================
            // CONFETTI
            // ==================================================

            Align(
              alignment:
                  Alignment.topCenter,
              child:
                  ConfettiWidget(
                confettiController:
                    confetti,
                blastDirectionality:
                    BlastDirectionality
                        .explosive,
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
    timer?.cancel();

    confetti.dispose();

    player.dispose();
    _musicPlayer.dispose();

    _shakeController.dispose();

    super.dispose();
  }
}