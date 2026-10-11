import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class DetectiveCase {
  final String title;
  final String image;
  final String story;
  final List<String> clues;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  const DetectiveCase({
    required this.title,
    required this.image,
    required this.story,
    required this.clues,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });
}

class LogicDetective extends StatefulWidget {
  const LogicDetective({super.key});

  @override
  State<LogicDetective> createState() => _LogicDetectiveState();
}

class _LogicDetectiveState extends State<LogicDetective> {
  static const int gameDuration = 60;
  static const int correctXp = 30;
  static const int wrongXp = 10;
  static const int correctScore = 1000;

  // How long the right/wrong answer stays highlighted before the
  // level complete screen appears.
  static const Duration answerRevealDelay = Duration(milliseconds: 1500);

  // Set this to false to turn score saving off completely
  // (for example while Firebase is not set up yet).
  static const bool enableScoreSaving = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  late DetectiveCase _currentCase;
  Timer? _timer;
  Timer? _resultsTimer;

  int _timeRemaining = gameDuration;
  int? _selectedAnswer;

  bool _isPaused = false;
  bool _finished = false; // An answer was chosen or time ran out.
  bool _showResults = false; // The level complete screen is visible.
  bool _isCorrect = false;
  bool _timedOut = false;

  final List<DetectiveCase> _cases = const [
    DetectiveCase(
      title: 'The Missing Red Pencil',
      image: 'assets/images/level7/missing_pencil.png',
      story: 'A student\'s red pencil has gone missing from the classroom '
          'desk. Look closely at the scene and work out where it is.',
      clues: [
        'The student was drawing on a sheet of paper before the pencil '
            'went missing.',
        'The drawing paper is still lying in the middle of the desk.',
        'A red pencil can be seen resting on the drawing paper.',
      ],
      choices: [
        'Inside the school bag',
        'On the drawing paper',
        'On the teacher\'s desk',
        'Inside the library',
      ],
      correctIndex: 1,
      explanation: 'The red pencil is lying right on top of the drawing '
          'paper, where the student left it. The picture and the clues '
          'point to the same place.',
    ),
    DetectiveCase(
      title: 'The Misplaced Library Book',
      image: 'assets/images/level7/library_book.png',
      story: 'A blue book was returned to the wrong shelf. '
          'Help the librarian work out where it belongs.',
      clues: [
        'The book cover shows planets and stars.',
        'The library has separate Space, Animals, and Plants sections.',
        'The blue book was found in the Animals section.',
      ],
      choices: [
        'The Space section',
        'The Animals section',
        'The Plants section',
        'The classroom cupboard',
      ],
      correctIndex: 0,
      explanation: 'A book about planets belongs in the Space section, '
          'not among books about animals.',
    ),
    DetectiveCase(
      title: 'The Science Fair Mix-Up',
      image: 'assets/images/level7/science_fair.png',
      story: 'Three science fair labels have been mixed up. '
          'Identify the project that belongs to Ana.',
      clues: [
        'Marco built a model of the solar system.',
        'Lia grew a bean plant for her experiment.',
        'Ana used baking soda and vinegar to make a volcano erupt.',
      ],
      choices: [
        'The bean plant experiment',
        'The solar system model',
        'The volcano model',
        'The water cycle poster',
      ],
      correctIndex: 2,
      explanation: 'Baking soda and vinegar create the bubbling reaction '
          'used in a classroom volcano demonstration. That is Ana\'s project.',
    ),
    DetectiveCase(
      title: 'The Garden Mystery',
      image: 'assets/images/level7/garden_mystery.png',
      story: 'The watering can has been moved from its usual place. '
          'Use the evidence to figure out who most likely moved it.',
      clues: [
        'The watering can was beside the flowerpots earlier.',
        'A trail of muddy footprints leads from the garden gate along '
            'the path.',
        'Leo was the only student recorded as entering the garden '
            'wearing muddy boots.',
      ],
      choices: [
        'Leo',
        'The librarian',
        'The science teacher',
        'A student who never entered the garden',
      ],
      correctIndex: 0,
      explanation: 'The footprints lead in from the gate, and the clue '
          'identifies Leo as the student wearing muddy boots who entered '
          'the garden. Based on the evidence, Leo is the most likely answer.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Pick one random case each time this screen is opened.
    _currentCase = _cases[_random.nextInt(_cases.length)];

    _startTimer();
  }

  // ------------------------------------------------------------
  // TIMER
  // ------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();

    if (_finished || _isPaused) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _finished || _isPaused) {
        timer.cancel();
        return;
      }

      if (_timeRemaining <= 1) {
        timer.cancel();
        setState(() => _timeRemaining = 0);
        _finishCase(correct: false, timedOut: true);
      } else {
        setState(() => _timeRemaining--);
      }
    });
  }

  // ------------------------------------------------------------
  // GAME LOGIC
  // ------------------------------------------------------------

  Future<void> _playSound(String filename) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$filename'));
    } catch (e) {
      debugPrint('Could not play sound $filename: $e');
    }
  }

  void _answerQuestion(int index) {
    if (_finished || _isPaused) return;

    setState(() => _selectedAnswer = index);

    _finishCase(correct: index == _currentCase.correctIndex);
  }

  void _finishCase({
    required bool correct,
    bool timedOut = false,
  }) {
    if (_finished) return;

    _timer?.cancel();

    setState(() {
      _finished = true;
      _isCorrect = correct;
      _timedOut = timedOut;
    });

    _playSound(correct ? 'correct.mp3' : 'wrong.mp3');

    // Save in the background. The screen never waits for this,
    // so a missing or slow database cannot freeze the game.
    unawaited(_saveScore(correct: correct, timedOut: timedOut));

    // Let the player see which answer was right, then show the
    // level complete screen.
    _resultsTimer?.cancel();
    _resultsTimer = Timer(answerRevealDelay, () {
      if (!mounted) return;

      setState(() => _showResults = true);

      if (correct) {
        _confettiController.play();
        _playSound('level up.mp3');
      }
    });
  }

  String get _grade {
    if (!_isCorrect) return 'D';
    return _timeRemaining >= 30 ? 'S' : 'A';
  }

  Future<void> _saveScore({
    required bool correct,
    required bool timedOut,
  }) async {
    if (!enableScoreSaving) return;

    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Logic Detective',
        'caseTitle': _currentCase.title,
        'correct': correct ? 1 : 0,
        'wrongAttempts': correct ? 0 : 1,
        'score': correct ? correctScore : 0,
        'xp': correct ? correctXp : wrongXp,
        'grade': _grade,
        'completed': true,
        'timedOut': timedOut,
        'timeRemaining': _timeRemaining,
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Not connected, not configured, or too slow: the game carries on.
      debugPrint('Could not save Logic Detective score: $e');
    }
  }

  // ------------------------------------------------------------
  // PAUSE / RESTART / NAVIGATION
  // ------------------------------------------------------------

  void _pauseGame() {
    if (_finished || _isPaused) return;

    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  void _resumeGame() {
    if (_finished) return;

    setState(() => _isPaused = false);
    _startTimer();
  }

  void _resetRound({required bool newCase}) {
    _timer?.cancel();
    _resultsTimer?.cancel();
    _audioPlayer.stop();

    if (newCase && _cases.length > 1) {
      final int current = _cases.indexOf(_currentCase);
      int next;
      do {
        next = _random.nextInt(_cases.length);
      } while (next == current);
      _currentCase = _cases[next];
    }

    setState(() {
      _timeRemaining = gameDuration;
      _selectedAnswer = null;
      _finished = false;
      _showResults = false;
      _isCorrect = false;
      _timedOut = false;
      _isPaused = false;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    _startTimer();
  }

  // Pause menu restart: same case again.
  void _restartGame() => _resetRound(newCase: false);

  // Level complete screen: a fresh random case.
  void _playAgain() => _resetRound(newCase: true);

  void _goToMainMenu() {
    _timer?.cancel();
    _resultsTimer?.cancel();
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------
  // IMAGE VIEWER
  // ------------------------------------------------------------

  Future<void> _openImage() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      // Taps on the picture itself do not close the viewer.
                      onTap: () {},
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(60),
                        child: Image.asset(
                          _currentCase.image,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.image_not_supported_outlined,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 32,
                      ),
                      tooltip: 'Close image',
                    ),
                  ),
                  const Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: Text(
                        'Pinch to zoom • Tap outside the picture to close',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // HEADER AND STATS
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _goToMainMenu,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          const Expanded(
            child: Text(
              'LOGIC DETECTIVE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: _finished ? null : _pauseGame,
            icon: Icon(
              Icons.pause_circle_filled,
              color: _finished ? Colors.white38 : Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final int earnedXp = _finished ? (_isCorrect ? correctXp : wrongXp) : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _buildStat(
            'TIME',
            '${_timeRemaining}s',
            _timeRemaining <= 10 ? Colors.redAccent : Colors.cyanAccent,
          ),
          const SizedBox(width: 5),
          _buildStat('LEVEL', '7', Colors.amber),
          const SizedBox(width: 5),
          _buildStat('XP', '$earnedXp', Colors.greenAccent),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // GAMEPLAY UI
  // ------------------------------------------------------------

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.3,
        fontSize: 12,
      ),
    );
  }

  Widget _buildCaseTitle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_special_rounded,
            size: 32,
            color: Color(0xFFFFD700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT CASE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentCase.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseImage() {
    // Keep the picture compact so the clues and answers are reachable
    // without a lot of scrolling. Tapping opens the full picture.
    final double imageHeight = (MediaQuery.of(context).size.height * 0.24)
        .clamp(150.0, 220.0)
        .toDouble();

    return GestureDetector(
      onTap: _openImage,
      child: Container(
        height: imageHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _currentCase.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_search_rounded,
                        size: 50,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add this case image to assets',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'Inspect image',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

  Widget _buildClueCard(int index, String clue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 26,
            width: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD700),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Color(0xFF4A0E4E),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              clue,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoice(int index) {
    final bool selected = _selectedAnswer == index;
    final bool isRightChoice = _finished && index == _currentCase.correctIndex;
    final bool isWrongPick = _finished && selected && !_isCorrect;

    Color background = Colors.white.withValues(alpha: 0.10);
    Color border = Colors.white.withValues(alpha: 0.25);
    Color badge = Colors.white.withValues(alpha: 0.16);
    Color badgeText = Colors.white;

    if (isRightChoice) {
      background = Colors.greenAccent.withValues(alpha: 0.22);
      border = Colors.greenAccent;
      badge = Colors.greenAccent;
      badgeText = const Color(0xFF4A0E4E);
    } else if (isWrongPick) {
      background = Colors.redAccent.withValues(alpha: 0.25);
      border = Colors.redAccent;
      badge = Colors.redAccent;
      badgeText = Colors.white;
    }

    return GestureDetector(
      onTap: (_finished || _isPaused) ? null : () => _answerQuestion(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            Container(
              height: 30,
              width: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badge,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  color: badgeText,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _currentCase.choices[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isRightChoice)
              const Icon(Icons.check_circle, color: Colors.greenAccent),
            if (isWrongPick)
              const Icon(Icons.cancel, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildGameplayScreen() {
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCaseTitle(),
            const SizedBox(height: 12),
            _buildCaseImage(),
            const SizedBox(height: 18),
            _sectionLabel('THE MYSTERY'),
            const SizedBox(height: 7),
            Text(
              _currentCase.story,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            _sectionLabel('EVIDENCE & CLUES'),
            const SizedBox(height: 10),
            ...List.generate(
              _currentCase.clues.length,
              (i) => _buildClueCard(i, _currentCase.clues[i]),
            ),
            const SizedBox(height: 10),
            _sectionLabel('WHO OR WHAT IS THE ANSWER?'),
            const SizedBox(height: 10),
            ...List.generate(_currentCase.choices.length, _buildChoice),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LEVEL COMPLETE SCREEN (same layout as Level 1)
  // ------------------------------------------------------------

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCompleteScreen() {
    final String subtitle = _isCorrect
        ? 'Case solved! Great detective work.'
        : _timedOut
            ? 'Time ran out and the case is still open.'
            : 'Not quite. Read the explanation below.';

    final String resultText = _isCorrect
        ? 'Solved ✅'
        : _timedOut
            ? 'Time\'s up ⏰'
            : 'Unsolved ❌';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 24,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎉 LEVEL COMPLETE!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD700),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // GRADE BADGE
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 4,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 15,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _grade,
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF811252),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // STATS CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow('Case:', _currentCase.title),
                        const Divider(color: Colors.white12),
                        _buildStatRow('Result:', resultText),
                        const Divider(color: Colors.white12),
                        _buildStatRow(
                          'XP Earned:',
                          '+${_isCorrect ? correctXp : wrongXp}',
                        ),
                        const Divider(color: Colors.white12),
                        _buildStatRow(
                          'Score:',
                          '${_isCorrect ? correctScore : 0} / $correctScore',
                        ),
                        const Divider(color: Colors.white12),
                        _buildStatRow('Time Left:', '${_timeRemaining}s'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // EXPLANATION CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isCorrect ? Colors.greenAccent : Colors.white24,
                        width: _isCorrect ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('WHAT HAPPENED'),
                        const SizedBox(height: 8),
                        Text(
                          _currentCase.explanation,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.45,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  _3DButton(
                    text: 'PLAY AGAIN',
                    color: const Color(0xFFFF8008),
                    shadowColor: const Color(0xFF993D00),
                    textColor: Colors.white,
                    onPressed: _playAgain,
                  ),

                  const SizedBox(height: 18),

                  _3DButton(
                    text: 'LEVEL MAP',
                    color: const Color(0xFFFF4081),
                    shadowColor: const Color(0xFF990033),
                    textColor: Colors.white,
                    onPressed: _goToMainMenu,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  if (!_showResults) _buildStats(),
                  Expanded(
                    child: _showResults
                        ? _buildLevelCompleteScreen()
                        : _buildGameplayScreen(),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 25,
                  maxBlastForce: 18,
                  minBlastForce: 8,
                  gravity: 0.25,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFF38EF7D),
                    Color(0xFFFF8008),
                    Colors.pink,
                    Colors.purple,
                  ],
                ),
              ),
              if (_isPaused)
                Positioned.fill(
                  child: PauseMenu(
                    onResume: _resumeGame,
                    onRestart: _restartGame,
                    onOptions: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Options will be available here later.',
                          ),
                        ),
                      );
                    },
                    onMainMenu: _goToMainMenu,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resultsTimer?.cancel();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}

// REUSABLE CHUNKY 3D GAME BUTTON (same as Level 1)
class _3DButton extends StatefulWidget {
  final String text;
  final Color color;
  final Color shadowColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _3DButton({
    required this.text,
    required this.color,
    required this.shadowColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  State<_3DButton> createState() => _3DButtonState();
}

class _3DButtonState extends State<_3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 200,
        height: 54,
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, _isPressed ? 1 : 5),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 6),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: TextStyle(
              color: widget.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}