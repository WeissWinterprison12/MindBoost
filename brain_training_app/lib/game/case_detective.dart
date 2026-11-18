import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/game_difficulty.dart';
import '../services/game_audio.dart';
import '../services/game_options_menu.dart';
import '../services/score_identity.dart';
import '../widgets/pause_menu.dart';
import 'tile_matrix.dart';

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

enum DetectiveDifficulty { easy, medium, hard }

class LogicDetective extends StatefulWidget {
  /// The difficulty picked on the level select screen.
  final GameDifficulty difficulty;

  const LogicDetective({
    super.key,
    this.difficulty = GameDifficulty.medium,
  });

  @override
  State<LogicDetective> createState() => _LogicDetectiveState();
}

class _LogicDetectiveState extends State<LogicDetective> {
  // The difficulty now comes from the level select screen.
  DetectiveDifficulty get _difficulty {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return DetectiveDifficulty.easy;
      case GameDifficulty.medium:
        return DetectiveDifficulty.medium;
      case GameDifficulty.hard:
        return DetectiveDifficulty.hard;
    }
  }

  int? get _timeLimit {
    switch (_difficulty) {
      case DetectiveDifficulty.easy: return null;
      case DetectiveDifficulty.medium: return 50;
      case DetectiveDifficulty.hard: return 20;
    }
  }

  int get _correctXp {
    switch (_difficulty) {
      case DetectiveDifficulty.easy: return 20;
      case DetectiveDifficulty.medium: return 30;
      case DetectiveDifficulty.hard: return 50;
    }
  }

  int get _wrongXp {
    switch (_difficulty) {
      case DetectiveDifficulty.easy: return 5;
      case DetectiveDifficulty.medium: return 10;
      case DetectiveDifficulty.hard: return 0;
    }
  }

  int get _correctScore {
    switch (_difficulty) {
      case DetectiveDifficulty.easy: return 500;
      case DetectiveDifficulty.medium: return 1000;
      case DetectiveDifficulty.hard: return 1500;
    }
  }

  String get _difficultyName {
    switch (_difficulty) {
      case DetectiveDifficulty.easy: return 'Easy';
      case DetectiveDifficulty.medium: return 'Medium';
      case DetectiveDifficulty.hard: return 'Hard';
    }
  }

  int get _earnedXp => _isCorrect ? _correctXp : _wrongXp;
  int get _earnedScore => _isCorrect ? _correctScore : 0;

  // How long the right/wrong answer stays highlighted before the
  // level complete screen appears.
  static const Duration answerRevealDelay = Duration(milliseconds: 1500);

  // Set this to false to turn score saving off completely
  // (for example while Firebase is not set up yet).
  static const bool enableScoreSaving = true;

  // Shared audio controller (music, effects, mute, ducking).
  final GameAudio audio = GameAudio(
    musicAsset: 'sounds/Closing_the_Paper_Trail.mp3',
  );

  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  late DetectiveCase _currentCase;
  Timer? _timer;
  Timer? _resultsTimer;

  int _timeRemaining = 50;
  int? _selectedAnswer;

  bool _isPaused = false;
  bool _showOptions = false;
  bool _finished = false; // An answer was chosen or time ran out.
  bool _showResults = false; // The level complete screen is visible.
  bool _isCorrect = false;
  bool _timedOut = false;

  // Progress message shown on the result screen (null while loading).
  _ProgressMessage? _progressMessage;

  // Increases every time a new round starts, so a slow history lookup
  // from an old round can never overwrite the message of a new round.
  int _session = 0;

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

    // The difficulty was already chosen on the level select screen,
    // so the case starts right away.
    _timeRemaining = _timeLimit ?? 0;
    _initAudio();
    _startTimer();
  }

  // ------------------------------------------------------------
  // AUDIO
  // ------------------------------------------------------------

  Future<void> _initAudio() async {
    await audio.init();
    if (!mounted) return;
    await audio.startMusic();
  }

  // ------------------------------------------------------------
  // TIMER
  // ------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();

    if (_finished || _isPaused || _timeLimit == null) {
      return;
    }

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

    if (correct) {
      audio.playCorrect();
    } else {
      audio.playWrong();
    }

    // Save in the background. The screen never waits for this,
    // so a missing or slow database cannot freeze the game.
    unawaited(_saveScore(correct: correct, timedOut: timedOut));

    // Let the player see which answer was right, then show the
    // level complete screen.
    _resultsTimer?.cancel();
    _resultsTimer = Timer(answerRevealDelay, () {
      if (!mounted) return;

      setState(() => _showResults = true);

      audio.stopMusic();

      if (correct) {
        _confettiController.play();
        audio.playComplete();
      }
    });
  }

  String get _grade {
    if (!_isCorrect) return 'D';
    if (_difficulty == DetectiveDifficulty.easy) return 'S';
    final threshold = _difficulty == DetectiveDifficulty.medium ? 25 : 10;
    return _timeRemaining >= threshold ? 'S' : 'A';
  }

  Future<void> _saveScore({
    required bool correct,
    required bool timedOut,
  }) async {
    // Remember which round this save belongs to.
    final int session = _session;

    if (!enableScoreSaving) {
      // No database, so there is no history to compare with.
      if (mounted && session == _session) {
        setState(() => _progressMessage = _buildProgressMessage(null));
      }
      return;
    }

    try {
      final identityFields = await ScoreIdentity.fields();

      // Compare against past games BEFORE saving this one, so the
      // current game isn't compared with itself.
      await _evaluateProgress(identityFields, session);

      final scoreReference =
          await FirebaseFirestore.instance.collection('scores').add({
        ...identityFields,
        'level': 6,
        'levelName': 'Case Detective',
        'difficulty': widget.difficulty.label,
        'caseTitle': _currentCase.title,
        'selectedAnswer': _selectedAnswer == null
            ? null
            : _currentCase.choices[_selectedAnswer!],
        'selectedAnswerIndex': _selectedAnswer,
        'correctAnswer': _currentCase.choices[_currentCase.correctIndex],
        'correctAnswerIndex': _currentCase.correctIndex,
        'correct': correct ? 1 : 0,
        'wrongAttempts': correct ? 0 : 1,
        'score': correct ? _correctScore : 0,
        'xp': correct ? _correctXp : _wrongXp,
        'grade': _grade,
        'completed': true,
        'timedOut': timedOut,
        'timeLimit': _timeLimit,
        'timeRemaining': _timeLimit == null ? null : _timeRemaining,
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
      await ScoreIdentity.recordRecentGame(scoreReference);
    } catch (e) {
      // Not connected, not configured, or too slow: the game carries on.
      debugPrint('Could not save Logic Detective score: $e');

      // Make sure the result screen never keeps spinning.
      if (mounted && session == _session && _progressMessage == null) {
        setState(() => _progressMessage = _buildProgressMessage(null));
      }
    }
  }

  // ------------------------------------------------------------
  // PROGRESS COMPARISON
  // (uses the same playedGameHistory as game_history.dart)
  // ------------------------------------------------------------

  // NOTE: this assumes ScoreIdentity.fields() contains the player id under
  // 'playerId', 'userId' or 'uid'. Change the keys below if yours differs.
  Future<List<Map<String, dynamic>>> _loadPreviousGames(
    Map<String, dynamic> identityFields,
  ) async {
    final playerId = (identityFields['playerId'] ??
            identityFields['userId'] ??
            identityFields['uid'])
        ?.toString();
    if (playerId == null || playerId.isEmpty) return [];

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(playerId)
        .get()
        .timeout(const Duration(seconds: 4));

    final raw = doc.data()?['playedGameHistory'];
    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((g) =>
            (g['levelName'] ?? g['gameName'] ?? g['game']) ==
                'Case Detective' &&
            g['difficulty'] == widget.difficulty.label)
        .toList(); // oldest -> newest (same order the history screen uses)
  }

  Future<void> _evaluateProgress(
    Map<String, dynamic> identityFields,
    int session,
  ) async {
    List<Map<String, dynamic>>? previous;
    try {
      previous = await _loadPreviousGames(identityFields);
    } catch (e) {
      // History could not be loaded: show a plain message instead of
      // wrongly claiming this is the player's first game.
      debugPrint('Could not load history: $e');
    }

    final message = _buildProgressMessage(previous);
    if (!mounted || session != _session) return;
    setState(() => _progressMessage = message);
  }

  _ProgressMessage _buildProgressMessage(List<Map<String, dynamic>>? previous) {
    bool solvedOf(Map<String, dynamic> g) =>
        (g['correct'] as num?)?.round() == 1;
    int timeOf(Map<String, dynamic> g) =>
        (g['timeRemaining'] as num?)?.round() ?? -1;

    // ---------- HISTORY NOT AVAILABLE ----------
    if (previous == null) {
      if (_isCorrect) {
        return _ProgressMessage(
          title: 'CASE SOLVED!',
          detail: 'You earned a grade $_grade and $_correctScore points. '
              'Great detective work!',
          icon: Icons.verified_rounded,
          color: Colors.amber,
        );
      }
      return _ProgressMessage(
        title: _timedOut ? 'TIME IS UP!' : 'CASE STILL OPEN',
        detail: 'Compare every clue with the picture and try again!',
        icon: _timedOut ? Icons.timer_off_rounded : Icons.search_rounded,
        color: Colors.redAccent,
      );
    }

    final solved = previous.where(solvedOf).toList();
    final bool timed = _timeLimit != null;

    // ---------- NOT SOLVED ----------
    if (!_isCorrect) {
      final speedTip = _timedOut ? ' Try to answer a little faster.' : '';

      if (previous.isEmpty) {
        return _ProgressMessage(
          title: _timedOut ? 'TIME IS UP!' : 'CASE STILL OPEN',
          detail: 'No case solved yet on this difficulty. Compare every '
              'clue with the picture and try again!$speedTip',
          icon: _timedOut ? Icons.timer_off_rounded : Icons.search_rounded,
          color: Colors.redAccent,
        );
      }
      if (solved.isNotEmpty) {
        return _ProgressMessage(
          title: 'SO CLOSE!',
          detail: 'You\'ve solved ${solved.length} '
              '${solved.length == 1 ? "case" : "cases"} on this difficulty '
              'before. Read the explanation and try again!$speedTip',
          icon: Icons.refresh_rounded,
          color: Colors.redAccent,
        );
      }
      return _ProgressMessage(
        title: 'KEEP INVESTIGATING!',
        detail: 'No case solved yet on this difficulty. Look at the '
            'picture and the clues together.$speedTip',
        icon: Icons.search_rounded,
        color: Colors.orangeAccent,
      );
    }

    // ---------- FIRST CASE SOLVED ----------
    if (solved.isEmpty) {
      return _ProgressMessage(
        title: 'FIRST CASE SOLVED!',
        detail: previous.isEmpty
            ? 'You earned a grade $_grade and $_correctScore points. '
                'That\'s your starting mark — can you beat it?'
            : 'You cracked it after ${previous.length} unsolved '
                '${previous.length == 1 ? "attempt" : "attempts"}. '
                'You earned a grade $_grade!',
        icon: Icons.flag_rounded,
        color: Colors.amber,
      );
    }

    final bool lastWasUnsolved = !solvedOf(previous.last);

    // Consecutive solved cases, counting this one.
    int run = 0;
    for (final g in previous.reversed) {
      if (solvedOf(g)) {
        run++;
      } else {
        break;
      }
    }
    final int streak = run + 1;

    // ---------- TIMED MODES: COMPARE SOLVE SPEED ----------
    final solvedTimes = solved.map(timeOf).where((t) => t >= 0).toList();

    if (timed && solvedTimes.isNotEmpty) {
      final int bestTime = solvedTimes.reduce(max);

      if (_timeRemaining > bestTime) {
        return _ProgressMessage(
          title: 'NEW FASTEST SOLVE!',
          detail: '${_timeRemaining - bestTime}s faster than your previous '
              'best (${bestTime}s left).',
          icon: Icons.emoji_events_rounded,
          color: Colors.amber,
        );
      }

      if (_timeRemaining == bestTime) {
        return _ProgressMessage(
          title: 'MATCHED YOUR FASTEST!',
          detail: 'You solved it as fast as your best — '
              '${_timeRemaining}s left.',
          icon: Icons.equalizer_rounded,
          color: Colors.lightGreenAccent,
        );
      }

      if (lastWasUnsolved) {
        return _ProgressMessage(
          title: 'BOUNCING BACK!',
          detail: 'You solved it after missing your last case. '
              'Your fastest left ${bestTime}s.',
          icon: Icons.replay_circle_filled_rounded,
          color: Colors.cyanAccent,
        );
      }

      final lastSolvedTime = solvedTimes.last;
      if (_timeRemaining > lastSolvedTime) {
        return _ProgressMessage(
          title: 'YOU\'RE IMPROVING!',
          detail: '${_timeRemaining - lastSolvedTime}s faster than your last '
              'solved case. Your fastest left ${bestTime}s.',
          icon: Icons.trending_up_rounded,
          color: Colors.cyanAccent,
        );
      }

      return _ProgressMessage(
        title: _grade == 'S' ? 'GREAT, BUT NOT YOUR FASTEST' : 'SOLVED, BUT SLOWER',
        detail: '${bestTime - _timeRemaining}s slower than your fastest '
            '(${bestTime}s left). Spot the key clue sooner next time.',
        icon: Icons.trending_down_rounded,
        color: Colors.orangeAccent,
      );
    }

    // ---------- EASY MODE (NO TIMER): COMPARE CONSISTENCY ----------
    if (lastWasUnsolved) {
      return _ProgressMessage(
        title: 'BOUNCING BACK!',
        detail: 'You solved it after missing your last case. '
            'You\'ve now solved ${solved.length + 1} cases on '
            '$_difficultyName.',
        icon: Icons.replay_circle_filled_rounded,
        color: Colors.cyanAccent,
      );
    }

    return _ProgressMessage(
      title: 'ON A ROLL!',
      detail: 'That\'s $streak cases solved in a row! '
          'You\'ve now solved ${solved.length + 1} cases on '
          '$_difficultyName.',
      icon: Icons.local_fire_department_rounded,
      color: Colors.amber,
    );
  }

  // ------------------------------------------------------------
  // PAUSE / RESTART / NAVIGATION
  // ------------------------------------------------------------

  void _pauseGame() {
    if (_finished || _isPaused) return;

    _timer?.cancel();

    audio.pauseAll();

    setState(() {
      _isPaused = true;
      _showOptions = false;
    });
  }

  Future<void> _resumeGame() async {
    if (_finished) return;

    setState(() {
      _isPaused = false;
      _showOptions = false;
    });

    await audio.resume();

    if (!mounted) return;

    _startTimer();
  }

  void _resetRound({required bool newCase}) {
    _timer?.cancel();
    _resultsTimer?.cancel();
    audio.stopEffects();
    _session++;

    if (newCase && _cases.length > 1) {
      final int current = _cases.indexOf(_currentCase);
      int next;
      do {
        next = _random.nextInt(_cases.length);
      } while (next == current);
      _currentCase = _cases[next];
    }

    setState(() {
      _timeRemaining = _timeLimit ?? 0;
      _selectedAnswer = null;
      _finished = false;
      _showResults = false;
      _isCorrect = false;
      _timedOut = false;
      _isPaused = false;
      _showOptions = false;
      _progressMessage = null;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    audio.startMusic();
    _startTimer();
  }

  // Pause menu restart: same case again.
  void _restartGame() => _resetRound(newCase: false);

  // Level complete screen: a fresh random case.
  void _playAgain() => _resetRound(newCase: true);

  void _goToMainMenu() {
    _timer?.cancel();
    _resultsTimer?.cancel();
    audio.stopMusic();
    Navigator.of(context).pop();
  }

  // PREVIOUS LEVEL → Level 5: Tile Matrix (same difficulty)
  void _goToPreviousLevel() {
    _timer?.cancel();
    _resultsTimer?.cancel();
    audio.stopMusic();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryMatrix(
          difficulty: widget.difficulty,
        ),
      ),
    );
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
          // Empty spacer (replaces the back button) so the
          // title stays centered in the header.
          const SizedBox(width: 48),

          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LEVEL 6: LOGIC DETECTIVE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.difficulty.label} MODE',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          IconButton(
            onPressed: _finished ? null : _pauseGame,
            icon: Icon(
              Icons.pause_circle_filled,
              color: _finished
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.amber,
              size: 32,
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
    final int earnedXp = _finished ? _earnedXp : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _buildStat(
            'TIME',
            _timeLimit == null ? '∞' : '${_timeRemaining}s',
            _timeLimit != null && _timeRemaining <= 10
                ? Colors.redAccent
                : Colors.cyanAccent,
          ),
          const SizedBox(width: 5),
          _buildStat('LEVEL', '6', Colors.amber),
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
  // RESULT SCREEN (same style as Picture Puzzle)
  // ------------------------------------------------------------

  Widget _buildChunkyButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool iconAfterText = false,
  }) {
    final iconWidget = Icon(icon, color: Colors.white, size: 20);
    final textWidget = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
          children: iconAfterText
              ? [textWidget, const SizedBox(width: 8), iconWidget]
              : [iconWidget, const SizedBox(width: 8), textWidget],
        ),
      ),
    );
  }

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

  Widget _buildProgressCard() {
    final message = _progressMessage;

    if (message == null) {
      return const Center(
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: message.color),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(message.icon, color: message.color, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: message.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message.detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCompleteScreen() {
    final bool solved = _isCorrect;

    final String title = solved
        ? '🎉 LEVEL COMPLETE!'
        : _timedOut
            ? '⏰ TIME IS UP!'
            : '😅 KEEP INVESTIGATING!';

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
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: solved ? Colors.amber : Colors.redAccent,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Progress message based on the player's history
                  _buildProgressCard(),
                  const SizedBox(height: 16),

                  if (solved) ...[
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
                        'GRADE: $_grade',
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
                      _buildStatBadge('🏆 Score', '$_earnedScore'),
                      _buildStatBadge('⭐ XP', '+$_earnedXp'),
                      _buildStatBadge(
                        '⏱ Time Left',
                        _timeLimit == null ? '∞' : '${_timeRemaining}s',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Text(
                    '🔍 ${_currentCase.title}  •  $_difficultyName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Explanation card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: solved ? Colors.greenAccent : Colors.white24,
                        width: solved ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('WHAT HAPPENED'),
                        const SizedBox(height: 6),
                        Text(
                          _currentCase.explanation,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Try Again (a fresh random case)
                  _buildChunkyButton(
                    label: 'Try Again',
                    icon: Icons.refresh_rounded,
                    color: const Color(0xFF2EC4B6),
                    onPressed: _playAgain,
                  ),
                  const SizedBox(height: 10),

                  // Previous level (same difficulty). Level 6 is the
                  // last level, so there is no Next button.
                  _buildChunkyButton(
                    label: 'Previous',
                    icon: Icons.arrow_back_rounded,
                    color: const Color(0xFF9B8AD6),
                    onPressed: _goToPreviousLevel,
                  ),
                  const SizedBox(height: 10),

                  // Level Map
                  _buildChunkyButton(
                    label: 'Level Map',
                    icon: Icons.home_rounded,
                    color: Colors.white24,
                    onPressed: _goToMainMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

              // Pause menu + shared options screen
              if (_isPaused)
                Positioned.fill(
                  child: _showOptions
                      ? GameOptionsMenu(
                          audio: audio,
                          onBack: () => setState(() => _showOptions = false),
                        )
                      : PauseMenu(
                          onResume: _resumeGame,
                          onRestart: _restartGame,
                          onOptions: () => setState(() => _showOptions = true),
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
    audio.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}

// ============================================================
// PROGRESS MESSAGE MODEL
// ============================================================

class _ProgressMessage {
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _ProgressMessage({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}