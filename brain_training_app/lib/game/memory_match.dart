import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class MemoryMatch extends StatefulWidget {
  const MemoryMatch({super.key});

  @override
  State<MemoryMatch> createState() => _MemoryMatchState();
}

class _MemoryMatchState extends State<MemoryMatch>
    with TickerProviderStateMixin {
  // ============================================================
  // GAME SETTINGS
  // ============================================================

  static const int totalPairs = 6;
  static const int totalCards = totalPairs * 2;

  static const int columns = 3;
  static const int rows = totalCards ~/ columns; // 4

  static const int previewDuration = 3;
  static const int gameDuration = 60;

  static const double cardSpacing = 8;
  static const double cardAspectRatio = 0.9; // width / height

  // ============================================================
  // CARD DATA
  // ============================================================

  final List<String> cardSymbols = [
    '🪐',
    '🐘',
    '🌱',
    '🔬',
    '🔢',
    '⭐',
  ];

  late List<String> cards;
  late List<bool> matched;
  late List<bool> revealed;

  // ============================================================
  // GAME STATE
  // ============================================================

  int? firstSelectedIndex;
  int? secondSelectedIndex;

  int moves = 0;
  int matchedPairs = 0;

  int previewSeconds = previewDuration;
  int gameSeconds = gameDuration;

  bool previewing = true;
  bool checkingPair = false;

  bool gameEnded = false;
  bool completed = false;
  bool isPaused = false;
  bool showOptions = false;

  // Audio volumes start at 50%.
  double musicVolume = 0.5;
  double soundVolume = 0.5;
  bool _musicStoppedForMute = false;

  // ============================================================
  // RESULTS
  // ============================================================

  int score = 0;
  int xp = 0;
  int streakCount = 0;

  // ============================================================
  // TIMERS
  // ============================================================

  Timer? timer;
  Timer? pairCheckTimer;

  // ============================================================
  // EFFECTS
  // ============================================================

  late ConfettiController confettiController;
  final AudioPlayer audioPlayer = AudioPlayer(); // Sound effects
  final AudioPlayer _musicPlayer = AudioPlayer(); // Background music

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    confettiController = ConfettiController(
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
      await audioPlayer.setAudioContext(audioContext);
      await audioPlayer.setVolume(soundVolume);
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
        AssetSource('sounds/The_Measured_Path.mp3'),
        volume: musicVolume,
      );
      _musicStoppedForMute = false;
    } catch (error) {
      debugPrint('Could not play background music: $error');
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
      await audioPlayer.setVolume(volume);
    } catch (error) {
      debugPrint('Could not change sound volume: $error');
    }
  }

  void showGameOptions() {
    if (!mounted) return;
    setState(() => showOptions = true);
  }

  // ============================================================
  // START / RESTART GAME
  // ============================================================

  void startNewGame() {
    timer?.cancel();
    pairCheckTimer?.cancel();

    final List<String> newCards = [];

    for (final symbol in cardSymbols) {
      newCards.add(symbol);
      newCards.add(symbol);
    }

    newCards.shuffle(Random());

    cards = newCards;

    matched = List<bool>.filled(totalCards, false);
    revealed = List<bool>.filled(totalCards, false);

    firstSelectedIndex = null;
    secondSelectedIndex = null;

    moves = 0;
    matchedPairs = 0;

    previewSeconds = previewDuration;
    gameSeconds = gameDuration;

    previewing = true;
    checkingPair = false;

    gameEnded = false;
    completed = false;
    isPaused = false;
    showOptions = false;

    score = 0;
    xp = 0;

    startPreview();
  }

  void restartGame() {
    timer?.cancel();
    pairCheckTimer?.cancel();

    audioPlayer.stop();
    _musicPlayer.stop();

    setState(() {
      startNewGame();
    });

    _startBackgroundMusic();
  }

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  void pauseGame() {
    if (gameEnded || completed || isPaused) return;

    timer?.cancel();
    pairCheckTimer?.cancel();

    audioPlayer.pause();
    _musicPlayer.pause();

    setState(() {
      isPaused = true;
      showOptions = false;
    });
  }

  Future<void> resumeGame() async {
    if (!isPaused || gameEnded || completed) return;

    setState(() {
      isPaused = false;
      showOptions = false;
    });

    try {
      await audioPlayer.setVolume(soundVolume);
      await audioPlayer.resume();
    } catch (error) {
      debugPrint('Could not resume sound effects: $error');
    }

    if (musicVolume > 0.0) {
      if (_musicStoppedForMute) {
        await _startBackgroundMusic();
      } else {
        try {
          await _musicPlayer.setVolume(musicVolume);
          await _musicPlayer.resume();
        } catch (error) {
          debugPrint('Could not resume background music: $error');
          await _startBackgroundMusic();
        }
      }
    }

    if (previewing) {
      startPreview();
    } else if (checkingPair) {
      // Resume the pending pair check without replaying its sound effect.
      checkPair(playFeedback: false);
      startGameTimer();
    } else {
      startGameTimer();
    }
  }

  // ============================================================
  // PREVIEW PHASE
  // ============================================================

  void startPreview() {
    timer?.cancel();

    revealed = List<bool>.filled(totalCards, true);

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        if (isPaused) return;

        setState(() {
          previewSeconds--;
        });

        if (previewSeconds <= 0) {
          t.cancel();

          setState(() {
            revealed = List<bool>.filled(totalCards, false);
            previewing = false;
          });

          startGameTimer();
        }
      },
    );
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

          _shakeController.forward(from: 0.0);

          playWrongSound();

          endGame(false);
        }
      },
    );
  }

  // ============================================================
  // CARD TAP
  // ============================================================

  void selectCard(int index) {
    if (previewing || isPaused) return;
    if (gameEnded || completed) return;
    if (checkingPair) return;
    if (matched[index]) return;
    if (revealed[index]) return;

    // First card.
    if (firstSelectedIndex == null) {
      setState(() {
        firstSelectedIndex = index;
        revealed[index] = true;
      });

      return;
    }

    // Same card.
    if (firstSelectedIndex == index) {
      return;
    }

    // Second card.
    setState(() {
      secondSelectedIndex = index;
      revealed[index] = true;
      checkingPair = true;
      moves++;
    });

    checkPair();
  }

  // ============================================================
  // CHECK PAIR
  // ============================================================

  void checkPair({bool playFeedback = true}) {
    if (firstSelectedIndex == null || secondSelectedIndex == null) {
      return;
    }

    pairCheckTimer?.cancel();

    // Determine the result immediately so the sound matches the player's move.
    // The 700 ms timer below only keeps both cards visible briefly before hiding
    // a mismatch or locking in a match.
    final int firstIndex = firstSelectedIndex!;
    final int secondIndex = secondSelectedIndex!;
    final bool isMatch = cards[firstIndex] == cards[secondIndex];

    if (playFeedback) {
      if (isMatch) {
        playCorrectSound();
      } else {
        playWrongSound();
      }
    }

    pairCheckTimer = Timer(
      const Duration(milliseconds: 700),
      () {
        if (!mounted) return;
        if (isPaused) return;

        if (isMatch) {
          setState(() {
            matched[firstIndex] = true;
            matched[secondIndex] = true;

            matchedPairs++;

            firstSelectedIndex = null;
            secondSelectedIndex = null;

            checkingPair = false;
          });

          if (matchedPairs >= totalPairs) {
            endGame(true);
          }
        } else {
          setState(() {
            revealed[firstIndex] = false;
            revealed[secondIndex] = false;

            firstSelectedIndex = null;
            secondSelectedIndex = null;

            checkingPair = false;
          });
        }
      },
    );
  }

  // ============================================================
  // SCORE CALCULATION
  // ============================================================

  void calculateResults() {
    final int timeUsed = gameDuration - gameSeconds;

    int calculatedScore = 1000;

    calculatedScore -= moves * 20;
    calculatedScore -= timeUsed * 5;

    if (calculatedScore < 0) {
      calculatedScore = 0;
    }

    score = calculatedScore;

    // Base XP.
    xp = 20;

    // Efficient matching bonus.
    if (moves <= 10) {
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
    if (gameEnded || isPaused) return;

    gameEnded = true;

    timer?.cancel();
    pairCheckTimer?.cancel();
    _musicPlayer.stop();

    if (win) {
      calculateResults();

      streakCount++;

      confettiController.play();

      playCompleteSound();
    } else {
      score = 0;
      xp = 0;
      streakCount = 0;
    }

    setState(() {
      completed = true;
    });

    saveScore(win);
  }

  // ============================================================
  // SAVE SCORE TO FIREBASE
  // ============================================================

  Future<void> saveScore(bool win) async {
    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Memory Match',
        'moves': moves,
        'matchedPairs': matchedPairs,
        'score': score,
        'xp': xp,
        'grade': win ? getGrade() : 'F',
        'completed': win,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error saving Memory Match score: $e');
    }
  }

  // ============================================================
  // SOUNDS
  // ============================================================

  Future<void> _playSound(String assetName) async {
    if (soundVolume <= 0.0 || !mounted) return;

    try {
      // Play immediately; stopping the player first added avoidable latency.
      await audioPlayer.play(
        AssetSource(assetName),
        volume: soundVolume,
      );
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void playCorrectSound() => _playSound('sounds/correct.mp3');

  void playWrongSound() => _playSound('sounds/wrong.mp3');

  void playCompleteSound() => _playSound('sounds/level up.mp3');

  // ============================================================
  // NAVIGATION
  // ============================================================

  void goToMainMenu() {
    Navigator.pop(context);
  }

  void goToNextLevel() {
    // Level 4 will be connected here later.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Level 4 will be connected here next!'),
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
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
                'Memory Match',
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
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
      ),
    );
  }

  // ============================================================
  // STAT BADGE
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

  // ============================================================
  // CARD WIDGET
  // ============================================================

  Widget buildCard(int index) {
    final bool isMatched = matched[index];
    final bool isVisible = revealed[index] || isMatched;
    final bool isSelected = firstSelectedIndex == index && !isMatched;

    return GestureDetector(
      onTap: () => selectCard(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: isVisible
              ? null
              : const LinearGradient(
                  colors: [
                    Color(0xFF6A1B9A),
                    Color(0xFF3949AB),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isVisible
              ? Colors.white.withValues(
                  alpha: isMatched ? 0.22 : 0.92,
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMatched
                ? Colors.greenAccent
                : isSelected
                    ? Colors.amber
                    : Colors.white24,
            width: isMatched || isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : isMatched
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isVisible
                ? FittedBox(
                    key: ValueKey('visible_$index'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        cards[index],
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  )
                : const Text(
                    '?',
                    key: ValueKey('hidden'),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD GRID
  // ============================================================

  Widget _buildCardGrid() {
    return LayoutBuilder(
      builder: (context, area) {
        final double maxWidth = min(area.maxWidth, 420.0);

        // Try to fit by width first.
        double cardWidth =
            (maxWidth - cardSpacing * (columns - 1)) / columns;
        double cardHeight = cardWidth / cardAspectRatio;

        double gridHeight =
            cardHeight * rows + cardSpacing * (rows - 1);

        // Too tall? Shrink to fit the height instead.
        if (gridHeight > area.maxHeight) {
          cardHeight =
              (area.maxHeight - cardSpacing * (rows - 1)) / rows;
          cardWidth = cardHeight * cardAspectRatio;
          gridHeight = area.maxHeight;
        }

        final double gridWidth =
            cardWidth * columns + cardSpacing * (columns - 1);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: cardSpacing,
                mainAxisSpacing: cardSpacing,
                childAspectRatio: cardAspectRatio,
              ),
              itemCount: totalCards,
              itemBuilder: (context, index) => buildCard(index),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // GAMEPLAY CONTENT
  // ============================================================

  Widget _buildGameplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // HUD
          Row(
            children: [
              Expanded(
                child: _buildHudCard(
                  icon: Icons.timer_outlined,
                  title: previewing ? 'PREVIEW' : 'TIME',
                  value: previewing
                      ? '${previewSeconds}s'
                      : '${gameSeconds}s',
                  valueColor:
                      previewing ? Colors.amber : Colors.cyanAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.psychology_alt_rounded,
                  title: 'PAIRS',
                  value: '$matchedPairs/$totalPairs',
                  valueColor: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.grid_view_rounded,
                  title: 'MOVES',
                  value: '$moves',
                  valueColor: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.local_fire_department,
                  title: 'STREAK',
                  value: '$streakCount',
                  valueColor: Colors.orangeAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            previewing ? 'MEMORIZE THE CARDS' : 'FIND THE PAIRS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: previewing ? Colors.amber : Colors.cyanAccent,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 10),

          // Cards take the remaining space
          Expanded(
            child: _buildCardGrid(),
          ),

          // Instruction
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              previewing
                  ? 'Remember the position of each symbol!'
                  : 'Tap two cards to reveal them',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULT SCREEN
  // ============================================================

  Widget buildResultScreen() {
    final bool passed = xp > 0;

    final int timeUsed = gameDuration - gameSeconds;

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
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
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
                        ? 'Excellent memory!'
                        : 'You did not match all the cards in time.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (passed) ...[
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

                  Text(
                    '🧠 Pairs: $matchedPairs/$totalPairs',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '⏱ Time Used: ${timeUsed}s',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (passed) ...[
                    _buildChunkyButton(
                      label: 'Next Level',
                      icon: Icons.arrow_forward_rounded,
                      color: const Color(0xFFFF9F1C),
                      onPressed: goToNextLevel,
                    ),
                    const SizedBox(height: 10),
                  ],

                  _buildChunkyButton(
                    label: 'Try Again',
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
  // OPTIONS SCREEN (audio controls)
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            activeColor: const Color(0xFFFFD700),
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('MUTED', style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text('MAX', style: TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ],
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
        child: Stack(
          children: [
            Column(
              children: [
                _buildCustomAppBar(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
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

            // Pause menu and options screen
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
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    timer?.cancel();
    pairCheckTimer?.cancel();

    confettiController.dispose();
    audioPlayer.dispose();
    _musicPlayer.dispose();
    _shakeController.dispose();

    super.dispose();
  }
}