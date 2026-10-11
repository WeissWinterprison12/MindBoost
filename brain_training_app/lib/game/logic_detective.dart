
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

  final AudioPlayer _audioPlayer = AudioPlayer();
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));
  final Random _random = Random();

  late DetectiveCase _currentCase;
  Timer? _timer;

  int _timeRemaining = gameDuration;
  int? _selectedAnswer;

  bool _isPaused = false;
  bool _finished = false;
  bool _isCorrect = false;
  bool _timedOut = false;
  bool _isSaving = false;

  final List<DetectiveCase> _cases = const [
    DetectiveCase(
      title: 'The Missing Red Pencil',
      image: 'assets/images/level7/missing_pencil.png',
      story:
          'A red pencil has disappeared from the classroom desk. '
          'Can you examine the scene and figure out where it is?',
      clues: [
        'The student was drawing a picture before the pencil disappeared.',
        'The drawing paper has not been moved off the desk.',
        'A small red pencil tip can be seen beneath the drawing paper.',
      ],
      choices: [
        'Inside the school bag',
        'Under the drawing paper',
        'On the teacher’s desk',
        'Inside the library',
      ],
      correctIndex: 1,
      explanation:
          'The red pencil tip is visible beneath the drawing paper. '
          'The picture and the clues point to the same location.',
    ),
    DetectiveCase(
      title: 'The Misplaced Library Book',
      image: 'assets/images/level7/library_book.png',
      story:
          'A blue book was returned to the wrong shelf. '
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
      explanation:
          'A book about planets belongs in the Space section, '
          'not among books about animals.',
    ),
    DetectiveCase(
      title: 'The Science Fair Mix-Up',
      image: 'assets/images/level7/science_fair.png',
      story:
          'Three science fair labels have been mixed up. '
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
      explanation:
          'Baking soda and vinegar can create the bubbling reaction '
          'used in a classroom volcano demonstration. That is Ana’s project.',
    ),
    DetectiveCase(
      title: 'The Garden Mystery',
      image: 'assets/images/level7/garden_mystery.png',
      story:
          'The watering can has been moved from its usual place. '
          'Use the evidence to figure out who most likely moved it.',
      clues: [
        'The watering can was beside the flowerpots earlier.',
        'A trail of muddy footprints leads from the garden gate to the pots.',
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
      explanation:
          'The footprints lead into the garden, and the clue identifies '
          'Leo as the student wearing muddy boots who entered it. '
          'Based on the evidence, Leo is the most likely answer.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Select one random case when a new game screen is opened.
    _currentCase = _cases[_random.nextInt(_cases.length)];

    _startTimer();
  }

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

  Future<void> _playSound(String filename) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$filename'));
    } catch (e) {
      debugPrint('Could not play sound $filename: $e');
    }
  }

  Future<void> _answerQuestion(int index) async {
    if (_finished || _isPaused) return;

    setState(() => _selectedAnswer = index);

    await _finishCase(
      correct: index == _currentCase.correctIndex,
    );
  }

  Future<void> _finishCase({
    required bool correct,
    bool timedOut = false,
  }) async {
    if (_finished) return;

    _timer?.cancel();

    setState(() {
      _finished = true;
      _isCorrect = correct;
      _timedOut = timedOut;
      _isSaving = true;
    });

    await _playSound(
      correct ? 'correct.mp3' : timedOut ? 'timeout.mp3' : 'wrong.mp3',
    );

    await _saveScore(correct: correct, timedOut: timedOut);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (correct) {
      _confettiController.play();
      await _playSound('level up.mp3');
    }
  }

  Future<void> _saveScore({
    required bool correct,
    required bool timedOut,
  }) async {
    final int score = correct ? 1000 : 0;
    final int xp = correct ? 30 : 10;
    final String grade = correct ? 'S' : 'D';

    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Logic Detective',
        'caseTitle': _currentCase.title,
        'correct': correct ? 1 : 0,
        'wrongAttempts': correct ? 0 : 1,
        'score': score,
        'xp': xp,
        'grade': grade,
        'completed': true,
        'timedOut': timedOut,
        'timeRemaining': _timeRemaining,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Could not save Logic Detective score: $e');
    }
  }

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

  void _restartGame() {
    _timer?.cancel();

    setState(() {
      _timeRemaining = gameDuration;
      _selectedAnswer = null;
      _finished = false;
      _isCorrect = false;
      _timedOut = false;
      _isSaving = false;
      _isPaused = false;
    });

    // Restart the same case. Opening a new game selects a new random case.
    _startTimer();
  }

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
                      // Taps on the picture do not close the viewer.
                      // Pinch to zoom and drag to inspect the image.
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

  Widget _buildCaseImage() {
    return GestureDetector(
      onTap: _openImage,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E2FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
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
                        size: 55,
                        color: Color(0xFF6941C6),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add this case image to assets',
                        style: TextStyle(
                          color: Color(0xFF6941C6),
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E2F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE7FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Color(0xFF6941C6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              clue,
              style: const TextStyle(
                color: Color(0xFF353044),
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

    Color background = Colors.white;
    Color border = const Color(0xFFE4DDF5);
    Color textColor = const Color(0xFF302A40);

    if (_finished && index == _currentCase.correctIndex) {
      background = const Color(0xFFD9F8E4);
      border = const Color(0xFF32A66A);
      textColor = const Color(0xFF17663C);
    } else if (_finished && selected && !_isCorrect) {
      background = const Color(0xFFFFE0E0);
      border = const Color(0xFFD9534F);
      textColor = const Color(0xFF9D2828);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _finished || _isPaused
              ? null
              : () => _answerQuestion(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: border.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentCase.choices[index],
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_finished && index == _currentCase.correctIndex)
                  const Icon(Icons.check_circle, color: Color(0xFF218653)),
                if (_finished && selected && !_isCorrect)
                  const Icon(Icons.cancel, color: Color(0xFFD9534F)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final Color resultColor = _isCorrect
        ? const Color(0xFF16834A)
        : const Color(0xFFB93838);

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isCorrect
            ? const Color(0xFFE1F8E9)
            : const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: resultColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCorrect ? Icons.stars_rounded : Icons.lightbulb_rounded,
                color: resultColor,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isCorrect
                      ? 'Case solved!'
                      : _timedOut
                          ? 'Time is up!'
                          : 'Not quite!',
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currentCase.explanation,
            style: const TextStyle(
              color: Color(0xFF373044),
              height: 1.45,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFE5A100)),
              const SizedBox(width: 5),
              Text(
                '+${_isCorrect ? 30 : 10} XP',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF5C4610),
                ),
              ),
              const Spacer(),
              Text(
                'Score: ${_isCorrect ? 1000 : 0}/1000',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF373044),
                ),
              ),
            ],
          ),
          if (_isSaving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 5),
            const Text(
              'Saving your score...',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                      // Return to the level map. Level 8 can be opened there.
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue to Level Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6941C6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF3EFFF),
              Color(0xFFF8F6FF),
              Color(0xFFEDE8FF),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _finished ? null : _pauseGame,
                          icon: const Icon(
                            Icons.pause_circle_filled_rounded,
                            size: 32,
                            color: Color(0xFF6941C6),
                          ),
                          tooltip: 'Pause game',
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LEVEL 7',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                  color: Color(0xFF796A9E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'LOGIC DETECTIVE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF352455),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _timeRemaining <= 10
                                ? const Color(0xFFFFE0E0)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _timeRemaining <= 10
                                  ? const Color(0xFFD9534F)
                                  : const Color(0xFFE3DDF2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                color: _timeRemaining <= 10
                                    ? const Color(0xFFD9534F)
                                    : const Color(0xFF6941C6),
                                size: 20,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$_timeRemaining s',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _timeRemaining <= 10
                                      ? const Color(0xFFD9534F)
                                      : const Color(0xFF352455),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.folder_special_rounded,
                                  size: 34,
                                  color: Color(0xFF6941C6),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CURRENT CASE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: 1.2,
                                          color: Color(0xFF796A9E),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _currentCase.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF352455),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildCaseImage(),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Tap the picture to inspect the evidence',
                              style: TextStyle(
                                color: Color(0xFF796A9E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'THE MYSTERY',
                            style: TextStyle(
                              color: Color(0xFF796A9E),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _currentCase.story,
                            style: const TextStyle(
                              color: Color(0xFF352F43),
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'EVIDENCE & CLUES',
                            style: TextStyle(
                              color: Color(0xFF796A9E),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(
                            _currentCase.clues.length,
                            (index) => _buildClueCard(
                              index,
                              _currentCase.clues[index],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'WHO OR WHAT IS THE ANSWER?',
                            style: TextStyle(
                              color: Color(0xFF796A9E),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(
                            _currentCase.choices.length,
                            _buildChoice,
                          ),
                          if (_finished) _buildResult(),
                        ],
                      ),
                    ),
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
                    onMainMenu: () {
                      Navigator.of(context).pop();
                    },
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
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}
