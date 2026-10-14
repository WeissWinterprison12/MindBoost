import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class WordPuzzle {
  final String answer;
  final List<String> images;
  final String hint;

  const WordPuzzle({
    required this.answer,
    required this.images,
    required this.hint,
  });
}

class WordQuestGame extends StatefulWidget {
  const WordQuestGame({super.key});

  @override
  State<WordQuestGame> createState() => _WordQuestGameState();
}

class _WordQuestGameState extends State<WordQuestGame>
    with TickerProviderStateMixin {
  // ============================================================
  // PUZZLE DATA
  // ============================================================

  final Random _random = Random();

  final List<WordPuzzle> _puzzles = const [
    WordPuzzle(
      answer: 'APPLE',
      hint: 'A fruit that can be red or green.',
      images: ['apple_1.jpg', 'apple_2.jpg', 'apple_3.jpg', 'apple_4.jpg'],
    ),
    WordPuzzle(
      answer: 'BOOK',
      hint: 'Something you read.',
      images: ['book_1.jpg', 'book_2.jpg', 'book_3.jpg', 'book_4.jpg'],
    ),
    WordPuzzle(
      answer: 'WATER',
      hint: 'Essential for life.',
      images: ['water_1.jpg', 'water_2.jpg', 'water_3.jpg', 'water_4.jpg'],
    ),
    WordPuzzle(
      answer: 'SCHOOL',
      hint: 'A place where students learn.',
      images: ['school_1.jpg', 'school_2.jpg', 'school_3.jpg', 'school_4.jpg'],
    ),
    WordPuzzle(
      answer: 'TREE',
      hint: 'A plant with a trunk and branches.',
      images: ['tree_1.jpg', 'tree_2.jpg', 'tree_3.jpg', 'tree_4.jpg'],
    ),
    WordPuzzle(
      answer: 'STAR',
      hint: 'A bright object seen in the night sky.',
      images: ['star_1.jpg', 'star_2.jpg', 'star_3.jpg', 'star_4.jpg'],
    ),
    WordPuzzle(
      answer: 'HEART',
      hint: 'An organ that pumps blood.',
      images: ['heart_1.jpg', 'heart_2.jpg', 'heart_3.jpg', 'heart_4.jpg'],
    ),
    WordPuzzle(
      answer: 'RAIN',
      hint: 'Water that falls from clouds.',
      images: ['rain_1.jpg', 'rain_2.jpg', 'rain_3.jpg', 'rain_4.jpg'],
    ),
    WordPuzzle(
      answer: 'CLOCK',
      hint: 'An object used to tell time.',
      images: ['clock_1.jpg', 'clock_2.jpg', 'clock_3.jpg', 'clock_4.jpg'],
    ),
    WordPuzzle(
      answer: 'BREAD',
      hint: 'A food commonly made from flour.',
      images: ['bread_1.jpg', 'bread_2.jpg', 'bread_3.jpg', 'bread_4.jpg'],
    ),
    WordPuzzle(
      answer: 'FISH',
      hint: 'An animal that lives underwater.',
      images: ['fish_1.jpg', 'fish_2.jpg', 'fish_3.jpg', 'fish_4.jpg'],
    ),
    WordPuzzle(
      answer: 'BRIDGE',
      hint: 'A structure that lets people cross an obstacle.',
      images: ['bridge_1.jpg', 'bridge_2.jpg', 'bridge_3.jpg', 'bridge_4.jpg'],
    ),
    WordPuzzle(
      answer: 'MUSIC',
      hint: 'Sounds arranged into a pleasing pattern.',
      images: ['music_1.jpg', 'music_2.jpg', 'music_3.jpg', 'music_4.jpg'],
    ),
    WordPuzzle(
      answer: 'PLANT',
      hint: 'A living thing that usually grows in soil.',
      images: ['plant_1.jpg', 'plant_2.jpg', 'plant_3.jpg', 'plant_4.jpg'],
    ),
    WordPuzzle(
      answer: 'FIRE',
      hint: 'Produces heat and light.',
      images: ['fire_1.jpg', 'fire_2.jpg', 'fire_3.jpg', 'fire_4.jpg'],
    ),
    WordPuzzle(
      answer: 'MOON',
      hint: 'Earth has one natural satellite.',
      images: ['moon_1.jpg', 'moon_2.jpg', 'moon_3.jpg', 'moon_4.jpg'],
    ),
    WordPuzzle(
      answer: 'TRAIN',
      hint: 'A vehicle that travels on railway tracks.',
      images: ['train_1.jpg', 'train_2.jpg', 'train_3.jpg', 'train_4.jpg'],
    ),
    WordPuzzle(
      answer: 'FLOWER',
      hint: 'A colorful part of many plants.',
      images: ['flower_1.jpg', 'flower_2.jpg', 'flower_3.jpg', 'flower_4.jpg'],
    ),
    WordPuzzle(
      answer: 'BALL',
      hint: 'A round object used in many games.',
      images: ['ball_1.jpg', 'ball_2.jpg', 'ball_3.jpg', 'ball_4.jpg'],
    ),
    WordPuzzle(
      answer: 'LIGHT',
      hint: 'Helps you see things around you.',
      images: ['light_1.jpg', 'light_2.jpg', 'light_3.jpg', 'light_4.jpg'],
    ),
  ];

  // ============================================================
  // GAME STATE
  // ============================================================

  static const int totalGameDuration = 30; // starting time (seconds)
  static const int maxHints = 3; // hints allowed per round
  static const int correctBonusSeconds = 5; // time added for a correct answer
  static const int wrongPenaltySeconds = 5; // time removed for a mistake

  Timer? _timer;

  int _timeLeft = totalGameDuration;
  int _xp = 0;
  int _wordsSolved = 0;
  int _attempts = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _currentPuzzleIndex = 0;
  int _puzzleStartTime = 0;
  int _correctAnswers = 0;
  int _hintsLeft = maxHints;

  bool _isPaused = false;
  bool _isFinished = false;
  bool _isChecking = false;
  bool _isSaving = false;
  bool _saveFailed = false;

  String _feedback = '';
  bool _lastAnswerCorrect = false;

  List<int> _remainingPuzzleIndexes = [];
  List<String> _displayImages = [];

  // Answer boxes + letter bank
  List<String> _letterBank = [];
  List<bool> _letterAvailable = [];
  List<int?> _answerSlots = [];
  List<bool> _hintLocked = [];

  bool _answerCorrect = false;
  bool _answerWrong = false;
  bool _hintUsed = false;

  // Index of the picture currently zoomed in (null = none).
  int? _zoomedImage;

  late ConfettiController _confetti;
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _shakeController;

  WordPuzzle get _currentPuzzle => _puzzles[_currentPuzzleIndex];

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    _confetti = ConfettiController(duration: const Duration(seconds: 2));

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _resetPuzzlePool();
    _loadNextPuzzle();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confetti.dispose();
    _player.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ============================================================
  // AUDIO
  // ============================================================

  Future<void> _playSound(String assetName) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(assetName));
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  // ============================================================
  // PUZZLE LOADING
  // ============================================================

  void _resetPuzzlePool() {
    _remainingPuzzleIndexes =
        List<int>.generate(_puzzles.length, (index) => index);
    _remainingPuzzleIndexes.shuffle(_random);
  }

  void _loadNextPuzzle() {
    if (_remainingPuzzleIndexes.isEmpty) {
      _resetPuzzlePool();
    }

    _currentPuzzleIndex = _remainingPuzzleIndexes.removeAt(0);

    final puzzle = _currentPuzzle;

    _displayImages = List<String>.of(puzzle.images)..shuffle(_random);

    // Answer boxes.
    _answerSlots = List<int?>.filled(puzzle.answer.length, null);
    _hintLocked = List<bool>.filled(puzzle.answer.length, false);

    // Correct letters + extra letters.
    _letterBank = puzzle.answer.split('');

    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    while (_letterBank.length < 12) {
      _letterBank.add(alphabet[_random.nextInt(alphabet.length)]);
    }

    _letterBank.shuffle(_random);
    _letterAvailable = List<bool>.filled(_letterBank.length, true);

    _puzzleStartTime = _timeLeft;
    _feedback = '';
    _lastAnswerCorrect = false;
    _isChecking = false;
    _answerCorrect = false;
    _answerWrong = false;
    _hintUsed = false;
    _zoomedImage = null;
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isPaused || _isFinished) return;

      if (_timeLeft <= 1) {
        setState(() {
          _timeLeft = 0;
          _isFinished = true;
          _isChecking = false;
        });

        timer.cancel();
        _finishGame();
        return;
      }

      setState(() {
        _timeLeft--;
      });
    });
  }

  // ============================================================
  // LETTER SELECTION
  // ============================================================

  void _selectTile(int index) {
    if (_isPaused || _isFinished || _isChecking) return;
    if (!_letterAvailable[index]) return;

    final emptySlot = _answerSlots.indexWhere((slot) => slot == null);

    if (emptySlot == -1) return;

    setState(() {
      _answerSlots[emptySlot] = index;
      _letterAvailable[index] = false;
      _feedback = '';
    });

    _playSound('sounds/pop.mp3');

    if (_answerSlots.every((slot) => slot != null)) {
      _checkAnswer();
    }
  }

  void _removeAnswerLetter(int slotIndex) {
    if (_isPaused || _isFinished || _isChecking) return;
    if (_hintLocked[slotIndex]) return;

    final bankIndex = _answerSlots[slotIndex];
    if (bankIndex == null) return;

    setState(() {
      _letterAvailable[bankIndex] = true;
      _answerSlots[slotIndex] = null;
      _feedback = '';
    });
  }

  // ============================================================
  // ANSWER CHECKING
  // ============================================================

  Future<void> _checkAnswer() async {
    if (_isPaused || _isFinished || _isChecking) return;

    final answer = _answerSlots
        .map((index) => index == null ? '' : _letterBank[index])
        .join();

    setState(() {
      _isChecking = true;
      _attempts++;
    });

    if (answer == _currentPuzzle.answer) {
      final secondsUsed = _puzzleStartTime - _timeLeft;
      final speedBonus = secondsUsed <= 5 ? 5 : 0;

      final nextStreak = _streak + 1;
      final streakBonus = nextStreak % 3 == 0 ? 5 : 0;
      final earnedXp = 10 + speedBonus + streakBonus;

      setState(() {
        _answerCorrect = true;
        _answerWrong = false;
        _correctAnswers++;
        _wordsSolved++;
        _streak = nextStreak;
        _bestStreak = max(_bestStreak, _streak);
        _xp += earnedXp;
        _timeLeft += correctBonusSeconds;
        _feedback = '+$earnedXp XP  •  +${correctBonusSeconds}s';
        _lastAnswerCorrect = true;
      });

      _playSound('sounds/click.mp3');

      await Future<void>.delayed(const Duration(seconds: 1));

      if (!mounted || _isFinished) return;

      setState(() {
        _loadNextPuzzle();
      });
    } else {
      setState(() {
        _answerWrong = true;
        _answerCorrect = false;
        _streak = 0;
        _timeLeft = max(0, _timeLeft - wrongPenaltySeconds);
        _feedback = 'Not quite!  •  -${wrongPenaltySeconds}s';
        _lastAnswerCorrect = false;
      });

      _shakeController.forward(from: 0.0);
      _playSound('sounds/wrong.mp3');

      await Future<void>.delayed(const Duration(milliseconds: 650));

      if (!mounted || _isFinished) return;

      // The penalty used up the remaining time.
      if (_timeLeft <= 0) {
        _endRoundNow();
        return;
      }

      setState(() {
        // Return incorrect letters to the bank, keeping hinted letters.
        for (int i = 0; i < _answerSlots.length; i++) {
          if (!_hintLocked[i]) {
            final bankIndex = _answerSlots[i];

            if (bankIndex != null) {
              _letterAvailable[bankIndex] = true;
              _answerSlots[i] = null;
            }
          }
        }

        _answerWrong = false;
        _isChecking = false;
        _feedback = '';
      });
    }
  }

  // ============================================================
  // END ROUND (time ran out from a penalty)
  // ============================================================

  void _endRoundNow() {
    _timer?.cancel();

    setState(() {
      _timeLeft = 0;
      _isFinished = true;
      _isChecking = false;
      _zoomedImage = null;
    });

    _finishGame();
  }

  // ============================================================
  // HINT
  // ============================================================

  void _useHint() {
    if (_isPaused || _isFinished || _isChecking) return;

    // No hints left for this round.
    if (_hintsLeft <= 0) {
      setState(() {
        _feedback = 'No hints left this round!';
        _lastAnswerCorrect = false;
      });
      return;
    }

    final emptySlots = <int>[];

    for (int i = 0; i < _answerSlots.length; i++) {
      if (_answerSlots[i] == null) {
        emptySlots.add(i);
      }
    }

    if (emptySlots.isEmpty) return;

    emptySlots.shuffle(_random);
    final slotIndex = emptySlots.first;

    final correctLetter = _currentPuzzle.answer[slotIndex];

    final matchingTiles = <int>[];

    for (int i = 0; i < _letterBank.length; i++) {
      if (_letterAvailable[i] && _letterBank[i] == correctLetter) {
        matchingTiles.add(i);
      }
    }

    if (matchingTiles.isEmpty) return;

    final bankIndex = matchingTiles[_random.nextInt(matchingTiles.length)];

    setState(() {
      _answerSlots[slotIndex] = bankIndex;
      _letterAvailable[bankIndex] = false;
      _hintLocked[slotIndex] = true;
      _hintUsed = true;
      _hintsLeft--;
      _feedback = 'Hint revealed!  ($_hintsLeft left)';
      _lastAnswerCorrect = true;
    });

    _playSound('sounds/pop.mp3');

    if (_answerSlots.every((slot) => slot != null)) {
      _checkAnswer();
    }
  }

  // ============================================================
  // PAUSE / RESUME / RESTART
  // ============================================================

  void _pauseGame() {
    if (_isFinished || _isPaused) return;

    _player.pause();

    setState(() {
      _isPaused = true;
      _zoomedImage = null;
    });
  }

  void _resumeGame() {
    if (!mounted || !_isPaused) return;

    setState(() {
      _isPaused = false;
    });

    _player.resume();
  }

  void _restartGame() {
    _timer?.cancel();

    setState(() {
      _timeLeft = totalGameDuration;
      _xp = 0;
      _wordsSolved = 0;
      _attempts = 0;
      _correctAnswers = 0;
      _streak = 0;
      _bestStreak = 0;
      _isPaused = false;
      _isFinished = false;
      _isChecking = false;
      _isSaving = false;
      _saveFailed = false;
      _feedback = '';
      _answerCorrect = false;
      _answerWrong = false;
      _hintUsed = false;
      _zoomedImage = null;
      _hintsLeft = maxHints;

      _resetPuzzlePool();
      _loadNextPuzzle();
    });

    _startTimer();
  }

  // ============================================================
  // FINISH + FIREBASE
  // ============================================================

  Future<void> _finishGame() async {
    if (_isSaving) return;

    _timer?.cancel();

    if (mounted) {
      setState(() {
        _isFinished = true;
        _isPaused = false;
        _isSaving = true;
      });
    }

    if (_wordsSolved > 0) {
      _confetti.play();
      _playSound('sounds/level up.mp3');
    } else {
      _playSound('sounds/wrong.mp3');
    }

    await _saveResult();
  }

  Future<void> _saveResult() async {
    try {
      final accuracy =
          _attempts == 0 ? 0.0 : (_correctAnswers / _attempts) * 100;

      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Word Quest',
        'wordsSolved': _wordsSolved,
        'xp': _xp,
        'streak': _bestStreak,
        'currentStreak': _streak,
        'attempts': _attempts,
        'correct': _correctAnswers,
        'accuracy': accuracy,
        'completed': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveFailed = false;
        });
      }
    } catch (e) {
      debugPrint('Word Quest score saving failed: $e');

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveFailed = true;
        });
      }
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _returnToMenu() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  // ============================================================
  // CHUNKY BUTTON
  // ============================================================

  Widget _buildChunkyButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double height = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
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
                'Word Quest',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: _pauseGame,
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
  // GLASS CONTAINER
  // ============================================================

  Widget _glass({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    double radius = 20,
    double alpha = 0.08,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
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
  // GAMEPLAY
  // ============================================================

  Widget _buildGameplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomInset = MediaQuery.of(context).padding.bottom;

        // Height used by everything except the picture grid.
        const fixedHeight = 450.0;

        // The picture grid takes whatever space is left over,
        // so the whole game fits on one screen.
        final pictureHeight =
            (constraints.maxHeight - fixedHeight - bottomInset)
                .clamp(120.0, 250.0);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
          child: Column(
            children: [
              // HUD
              Row(
                children: [
                  _buildHudCard(
                    icon: Icons.timer_outlined,
                    title: 'TIME',
                    value: '${_timeLeft}s',
                    valueColor:
                        _timeLeft <= 10 ? Colors.redAccent : Colors.cyanAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildHudCard(
                    icon: Icons.check_circle_outline,
                    title: 'SOLVED',
                    value: '$_wordsSolved',
                    valueColor: Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildHudCard(
                    icon: Icons.bolt_rounded,
                    title: 'XP',
                    value: '$_xp',
                    valueColor: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  _buildHudCard(
                    icon: Icons.local_fire_department,
                    title: 'STREAK',
                    value: '$_streak',
                    valueColor: Colors.orangeAccent,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              const Text(
                'FOUR PICS, ONE WORD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.cyanAccent,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              _buildPictureGrid(pictureHeight),

              const SizedBox(height: 8),

              _buildHintCard(),

              const SizedBox(height: 10),

              _buildAnswerBoxes(),

              const SizedBox(height: 12),

              _buildLetterBank(),

              const SizedBox(height: 10),

              _buildHintButton(),

              const SizedBox(height: 6),

              _buildFeedback(),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // PICTURE GRID
  // ============================================================

  Widget _buildPictureGrid(double height) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildPictureCell(0)),
                const SizedBox(width: 6),
                Expanded(child: _buildPictureCell(1)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildPictureCell(2)),
                const SizedBox(width: 6),
                Expanded(child: _buildPictureCell(3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPictureCell(int index) {
    if (index >= _displayImages.length) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isPaused || _isFinished) return;

        setState(() {
          _zoomedImage = index;
        });
      },
      child: _buildPictureCellContent(index),
    );
  }

  Widget _buildPictureCellContent(int index) {

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/level9/${_displayImages[index]}',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white70,
                      size: 26,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CLUE CARD
  // ============================================================

  Widget _buildHintCard() {
    return _glass(
      radius: 14,
      alpha: 0.1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEED A CLUE?',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentPuzzle.hint,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANSWER BOXES
  // ============================================================

  Widget _buildAnswerBoxes() {
    return Column(
      children: [
        const Text(
          'YOUR ANSWER',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 8,
          children: List.generate(_answerSlots.length, (index) {
            final bankIndex = _answerSlots[index];

            Color boxColor = Colors.white.withValues(alpha: 0.12);
            Color borderColor = Colors.white38;

            if (_answerCorrect) {
              boxColor = const Color(0xFF2EC4B6).withValues(alpha: 0.7);
              borderColor = Colors.greenAccent;
            } else if (_answerWrong) {
              boxColor = Colors.redAccent.withValues(alpha: 0.6);
              borderColor = Colors.redAccent;
            } else if (_hintLocked[index]) {
              boxColor = Colors.amber.withValues(alpha: 0.2);
              borderColor = Colors.amber;
            }

            return GestureDetector(
              onTap: () => _removeAnswerLetter(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _answerSlots.length >= 7 ? 36 : 42,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Text(
                  bankIndex == null ? '' : _letterBank[bankIndex],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ============================================================
  // LETTER BANK (always 12 tiles = 2 rows of 6)
  // ============================================================

  Widget _buildLetterBank() {
    return Column(
      children: [
        const Text(
          'CHOOSE YOUR LETTERS',
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _letterBank.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) {
            final available = _letterAvailable[index];

            return GestureDetector(
              onTap: available ? () => _selectTile(index) : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: available ? 1.0 : 0.18,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    _letterBank[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // HINT BUTTON
  // ============================================================

  Widget _buildHintButton() {
    final noHints = _hintsLeft <= 0;
    final disabled = _isChecking || _isPaused || _isFinished || noHints;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: _buildChunkyButton(
        label: noHints ? 'NO HINTS LEFT' : 'USE HINT  ($_hintsLeft/$maxHints)',
        icon: Icons.lightbulb_rounded,
        color: noHints ? Colors.white24 : const Color(0xFFFF9F1C),
        height: 44,
        onPressed: () {
          if (!disabled) _useHint();
        },
      ),
    );
  }

  // ============================================================
  // FEEDBACK (fixed height so the layout never jumps)
  // ============================================================

  Widget _buildFeedback() {
    final color = _lastAnswerCorrect ? Colors.greenAccent : Colors.redAccent;

    return SizedBox(
      height: 36,
      child: _feedback.isEmpty
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
                _feedback,
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
    final accuracy = _attempts == 0 ? 0.0 : (_correctAnswers / _attempts) * 100;
    final bool solvedAny = _wordsSolved > 0;

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
                    solvedAny ? '🎉 TIME\'S UP!' : '⏰ TIME\'S UP!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: solvedAny ? Colors.amber : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    solvedAny
                        ? 'Great effort on Word Quest!'
                        : 'No words solved this time. Try again!',
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
                      '⭐ $_xp XP',
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
                      _buildStatBadge('🧩 Solved', '$_wordsSolved'),
                      _buildStatBadge('🔥 Best Streak', '$_bestStreak'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBadge('👆 Attempts', '$_attempts'),
                      _buildStatBadge(
                        '🎯 Accuracy',
                        '${accuracy.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isSaving)
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
                  else if (_saveFailed)
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
                  if (_saveFailed) ...[
                    const SizedBox(height: 10),
                    _buildChunkyButton(
                      label: 'Retry Saving',
                      icon: Icons.cloud_upload_rounded,
                      color: const Color(0xFFFF9F1C),
                      onPressed: () {
                        setState(() {
                          _isSaving = true;
                          _saveFailed = false;
                        });
                        _saveResult();
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildChunkyButton(
                    label: 'Main Menu',
                    icon: Icons.home_rounded,
                    color: Colors.white24,
                    onPressed: _returnToMenu,
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
  // ZOOM OVERLAY
  // ============================================================

  Widget _buildZoomOverlay() {
    final imageName = _displayImages[_zoomedImage!];

    return Positioned.fill(
      child: GestureDetector(
        // Tapping anywhere closes the zoomed picture.
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _zoomedImage = null;
          });
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.88),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_zoomedImage),
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(scale: value, child: child),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white38, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/level9/$imageName',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              alignment: Alignment.center,
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white70,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tap anywhere to close',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
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
                  child: AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      // Wobble left/right and settle back to exactly 0.
                      final t = _shakeController.value;
                      final dx = sin(t * pi * 6) * 8 * (1 - t);

                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child:
                        _isFinished ? _buildResultScreen() : _buildGameplay(),
                  ),
                ),
              ],
            ),

            // Zoomed picture
            if (_zoomedImage != null &&
                !_isFinished &&
                !_isPaused &&
                _zoomedImage! < _displayImages.length)
              _buildZoomOverlay(),

            // Pause menu
            if (_isPaused && !_isFinished)
              Positioned.fill(
                child: PauseMenu(
                  onResume: _resumeGame,
                  onRestart: _restartGame,
                  onOptions: () {},
                  onMainMenu: _returnToMenu,
                ),
              ),

            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
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