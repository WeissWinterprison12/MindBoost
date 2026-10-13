
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

class _WordQuestGameState extends State<WordQuestGame> {
  final Random _random = Random();

  final List<WordPuzzle> _puzzles = const [
    WordPuzzle(
      answer: 'APPLE',
      hint: 'A fruit that can be red or green.',
      images: [
        'apple_1.jpg',
        'apple_2.jpg',
        'apple_3.jpg',
        'apple_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'BOOK',
      hint: 'Something you read.',
      images: [
        'book_1.jpg',
        'book_2.jpg',
        'book_3.jpg',
        'book_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'WATER',
      hint: 'Essential for life.',
      images: [
        'water_1.jpg',
        'water_2.jpg',
        'water_3.jpg',
        'water_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'SCHOOL',
      hint: 'A place where students learn.',
      images: [
        'school_1.jpg',
        'school_2.jpg',
        'school_3.jpg',
        'school_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'TREE',
      hint: 'A plant with a trunk and branches.',
      images: [
        'tree_1.jpg',
        'tree_2.jpg',
        'tree_3.jpg',
        'tree_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'STAR',
      hint: 'A bright object seen in the night sky.',
      images: [
        'star_1.jpg',
        'star_2.jpg',
        'star_3.jpg',
        'star_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'HEART',
      hint: 'An organ that pumps blood.',
      images: [
        'heart_1.jpg',
        'heart_2.jpg',
        'heart_3.jpg',
        'heart_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'RAIN',
      hint: 'Water that falls from clouds.',
      images: [
        'rain_1.jpg',
        'rain_2.jpg',
        'rain_3.jpg',
        'rain_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'CLOCK',
      hint: 'An object used to tell time.',
      images: [
        'clock_1.jpg',
        'clock_2.jpg',
        'clock_3.jpg',
        'clock_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'BREAD',
      hint: 'A food commonly made from flour.',
      images: [
        'bread_1.jpg',
        'bread_2.jpg',
        'bread_3.jpg',
        'bread_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'FISH',
      hint: 'An animal that lives underwater.',
      images: [
        'fish_1.jpg',
        'fish_2.jpg',
        'fish_3.jpg',
        'fish_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'BRIDGE',
      hint: 'A structure that lets people cross an obstacle.',
      images: [
        'bridge_1.jpg',
        'bridge_2.jpg',
        'bridge_3.jpg',
        'bridge_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'MUSIC',
      hint: 'Sounds arranged into a pleasing pattern.',
      images: [
        'music_1.jpg',
        'music_2.jpg',
        'music_3.jpg',
        'music_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'PLANT',
      hint: 'A living thing that usually grows in soil.',
      images: [
        'plant_1.jpg',
        'plant_2.jpg',
        'plant_3.jpg',
        'plant_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'FIRE',
      hint: 'Produces heat and light.',
      images: [
        'fire_1.jpg',
        'fire_2.jpg',
        'fire_3.jpg',
        'fire_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'MOON',
      hint: 'Earth has one natural satellite.',
      images: [
        'moon_1.jpg',
        'moon_2.jpg',
        'moon_3.jpg',
        'moon_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'TRAIN',
      hint: 'A vehicle that travels on railway tracks.',
      images: [
        'train_1.jpg',
        'train_2.jpg',
        'train_3.jpg',
        'train_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'FLOWER',
      hint: 'A colorful part of many plants.',
      images: [
        'flower_1.jpg',
        'flower_2.jpg',
        'flower_3.jpg',
        'flower_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'BALL',
      hint: 'A round object used in many games.',
      images: [
        'ball_1.jpg',
        'ball_2.jpg',
        'ball_3.jpg',
        'ball_4.jpg',
      ],
    ),
    WordPuzzle(
      answer: 'LIGHT',
      hint: 'Helps you see things around you.',
      images: [
        'light_1.jpg',
        'light_2.jpg',
        'light_3.jpg',
        'light_4.jpg',
      ],
    ),
  ];

  Timer? _timer;

  int _timeLeft = 60;
  int _xp = 0;
  int _wordsSolved = 0;
  int _attempts = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _selectedTile = -1;
  int _currentPuzzleIndex = 0;
  int _puzzleStartTime = 0;

  int _correctAnswers = 0;

  bool _isPaused = false;
  bool _isFinished = false;
  bool _isChecking = false;
  bool _isSaving = false;
  bool _saveFailed = false;

  String _feedback = '';
  bool _lastAnswerCorrect = false;

  List<int> _remainingPuzzleIndexes = [];
  List<String> _displayImages = [];
  List<String> _letters = [];

  WordPuzzle get _currentPuzzle => _puzzles[_currentPuzzleIndex];

  @override
  void initState() {
    super.initState();
    _resetPuzzlePool();
    _loadNextPuzzle();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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

    _displayImages = List<String>.of(puzzle.images)
      ..shuffle(_random);

    _letters = puzzle.answer.split('')..shuffle(_random);

    // Try to avoid displaying the answer already in order.
    if (_letters.join() == puzzle.answer && _letters.length > 1) {
      _letters.shuffle(_random);
      if (_letters.join() == puzzle.answer) {
        _letters.insert(0, _letters.removeAt(1));
      }
    }

    _selectedTile = -1;
    _puzzleStartTime = _timeLeft;
    _feedback = '';
    _lastAnswerCorrect = false;
    _isChecking = false;
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused || _isFinished) return;

      if (_timeLeft <= 1) {
        setState(() {
          _timeLeft = 0;
          _isFinished = true;
          _isChecking = false;
          _selectedTile = -1;
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

  void _selectTile(int index) {
    if (_isPaused || _isFinished || _isChecking) return;

    setState(() {
      _feedback = '';

      if (_selectedTile == -1) {
        _selectedTile = index;
      } else if (_selectedTile == index) {
        _selectedTile = -1;
      } else {
        final temp = _letters[_selectedTile];
        _letters[_selectedTile] = _letters[index];
        _letters[index] = temp;
        _selectedTile = -1;
      }
    });
  }

  Future<void> _checkAnswer() async {
    if (_isPaused || _isFinished || _isChecking) return;

    setState(() {
      _attempts++;
      _selectedTile = -1;
    });

    if (_letters.join() != _currentPuzzle.answer) {
      setState(() {
        _streak = 0;
        _feedback = 'Not quite! Keep rearranging the letters.';
        _lastAnswerCorrect = false;
      });
      return;
    }

    final secondsUsed = _puzzleStartTime - _timeLeft;

    final speedBonus = secondsUsed <= 5 ? 5 : 0;
    final nextStreak = _streak + 1;
    final streakBonus = nextStreak % 3 == 0 ? 5 : 0;
    final earnedXp = 10 + speedBonus + streakBonus;

    setState(() {
      _isChecking = true;
      _correctAnswers++;
      _wordsSolved++;
      _streak = nextStreak;
      _bestStreak = max(_bestStreak, _streak);
      _xp += earnedXp;
      _timeLeft += 2;
      _feedback = '+$earnedXp XP! Correct answer!';
      _lastAnswerCorrect = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted || _isFinished) return;

    setState(() {
      _loadNextPuzzle();
    });
  }

  void _pauseGame() {
    if (_isFinished || _isPaused) return;

    setState(() {
      _isPaused = true;
      _selectedTile = -1;
    });
  }

  void _resumeGame() {
    if (!mounted) return;

    setState(() {
      _isPaused = false;
    });
  }

  void _restartGame() {
    _timer?.cancel();

    setState(() {
      _timeLeft = 60;
      _xp = 0;
      _wordsSolved = 0;
      _attempts = 0;
      _correctAnswers = 0;
      _streak = 0;
      _bestStreak = 0;
      _selectedTile = -1;
      _isPaused = false;
      _isFinished = false;
      _isChecking = false;
      _isSaving = false;
      _saveFailed = false;
      _feedback = '';

      _resetPuzzlePool();
      _loadNextPuzzle();
    });

    _startTimer();
  }

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

    await _saveResult();
  }

  Future<void> _saveResult() async {
    try {
      final accuracy = _attempts == 0
          ? 0.0
          : (_correctAnswers / _attempts) * 100;

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

  void _returnToMenu() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  String get _formattedTime {
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101329),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF222957),
                      Color(0xFF101329),
                      Color(0xFF15152D),
                    ],
                  ),
                ),
              ),
            ),
            if (_isFinished)
              _buildResultScreen()
            else
              _buildGameScreen(),
            if (_isPaused && !_isFinished) _buildPauseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: Column(
              children: [
                _buildStatsRow(),
                const SizedBox(height: 18),
                _buildPictureGrid(),
                const SizedBox(height: 20),
                _buildHintCard(),
                const SizedBox(height: 18),
                _buildLetterTiles(),
                const SizedBox(height: 18),
                _buildFeedback(),
                const SizedBox(height: 12),
                _buildSubmitButton(),
                const SizedBox(height: 12),
                Text(
                  'Tap two letters to swap their positions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _pauseGame,
            tooltip: 'Pause game',
            icon: const Icon(
              Icons.pause_circle_filled_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WORD QUEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'LEVEL 9 • FOUR PICS, ONE WORD',
                  style: TextStyle(
                    color: Color(0xFFB9C5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: _timeLeft <= 10
                  ? const Color(0xFF8F303F)
                  : const Color(0xFF292F55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _timeLeft <= 10
                    ? const Color(0xFFFF7287)
                    : const Color(0xFF555F9A),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  _formattedTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_rounded,
            label: 'SOLVED',
            value: '$_wordsSolved',
            color: const Color(0xFF64E6B2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.bolt_rounded,
            label: 'TOTAL XP',
            value: '$_xp',
            color: const Color(0xFFFFD166),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department_rounded,
            label: 'STREAK',
            value: '$_streak',
            color: const Color(0xFFFF9875),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF202544),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPictureGrid() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2140),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF444D7B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _displayImages.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: 1.22,
        ),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/${_displayImages[index]}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF303657),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white70,
                            size: 30,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Image not found',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 7,
                  left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF292F55),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF626FAE).withOpacity(0.60),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: Color(0xFFFFD166),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEED A CLUE?',
                  style: TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _currentPuzzle.hint,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
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

  Widget _buildLetterTiles() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 7,
      runSpacing: 10,
      children: List.generate(_letters.length, (index) {
        final isSelected = _selectedTile == index;

        return GestureDetector(
          onTap: () => _selectTile(index),
          child: AnimatedScale(
            scale: isSelected ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: _letters.length >= 7 ? 39 : 46,
              height: _letters.length >= 7 ? 48 : 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFD166)
                    : const Color(0xFF313961),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFFE7A2)
                      : const Color(0xFF6673B4),
                  width: isSelected ? 2.5 : 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFFFD166).withOpacity(0.25)
                        : Colors.black.withOpacity(0.12),
                    blurRadius: isSelected ? 12 : 4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _letters[index],
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF24233A)
                      : Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFeedback() {
    if (_feedback.isEmpty) {
      return const SizedBox(height: 24);
    }

    final color = _lastAnswerCorrect
        ? const Color(0xFF64E6B2)
        : const Color(0xFFFFB3A6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.55)),
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
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed:
            _isChecking || _isPaused || _isFinished ? null : _checkAnswer,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C83FF),
          disabledBackgroundColor: const Color(0xFF41466D),
          foregroundColor: Colors.white,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isChecking
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 22),
                  SizedBox(width: 9),
                  Text(
                    'SUBMIT WORD',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.78),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF202544),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFF6572B5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  color: Color(0xFFFFD166),
                  size: 66,
                ),
                const SizedBox(height: 10),
                const Text(
                  'GAME PAUSED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a breath. Your timer is stopped.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 25),
                _pauseButton(
                  label: 'RESUME',
                  icon: Icons.play_arrow_rounded,
                  color: const Color(0xFF64DDA9),
                  onTap: _resumeGame,
                ),
                const SizedBox(height: 11),
                _pauseButton(
                  label: 'RESTART',
                  icon: Icons.restart_alt_rounded,
                  color: const Color(0xFF7C83FF),
                  onTap: _confirmRestart,
                ),
                const SizedBox(height: 11),
                _pauseButton(
                  label: 'MAIN MENU',
                  icon: Icons.home_rounded,
                  color: const Color(0xFF41476C),
                  onTap: _confirmMainMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 49,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF252B4D),
        title: const Text(
          'Restart Word Quest?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your current round progress will be reset.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('RESTART'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _restartGame();
    }
  }

  Future<void> _confirmMainMenu() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF252B4D),
        title: const Text(
          'Return to Main Menu?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your current round progress will end.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('MAIN MENU'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _returnToMenu();
    }
  }

  Widget _buildResultScreen() {
    final accuracy = _attempts == 0
        ? 0.0
        : (_correctAnswers / _attempts) * 100;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF202544),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF6572B5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFFD166),
                size: 78,
              ),
              const SizedBox(height: 10),
              const Text(
                'TIME\'S UP!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Great effort on Word Quest!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 23),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF30375F),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL EXPERIENCE',
                      style: TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_xp XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 37,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: _resultStat(
                      'WORDS SOLVED',
                      '$_wordsSolved',
                      Icons.check_circle_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _resultStat(
                      'BEST STREAK',
                      '$_bestStreak',
                      Icons.local_fire_department_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _resultStat(
                      'ATTEMPTS',
                      '$_attempts',
                      Icons.touch_app_rounded,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _resultStat(
                      'ACCURACY',
                      '${accuracy.toStringAsFixed(0)}%',
                      Icons.track_changes_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              if (_isSaving)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFB9C5FF),
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
                    color: Color(0xFF64E6B2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(
                    'PLAY AGAIN',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C83FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _returnToMenu,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text(
                    'MAIN MENU',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF6572B5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              if (_saveFailed) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _saveFailed = false;
                    });
                    _saveResult();
                  },
                  child: const Text('RETRY SAVING SCORE'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF292F55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB9C5FF), size: 23),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}