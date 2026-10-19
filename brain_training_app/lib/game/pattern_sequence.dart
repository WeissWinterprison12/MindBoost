import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

/// The stages of the combined level.
///   pattern  -> Part 1 (Pattern Logic questions)
///   intro    -> short "Part 1 done" screen before Part 2
///   sequence -> Part 2 (Sequence Recall rounds)
///   result   -> final result card
enum GameStage { pattern, intro, sequence, result }

class PatternSequence extends StatefulWidget {
  const PatternSequence({super.key});

  @override
  State<PatternSequence> createState() => _PatternSequenceState();
}

class _PatternSequenceState extends State<PatternSequence>
    with TickerProviderStateMixin {
  // ============================================================
  // SETTINGS  (tweak these to change the game length / difficulty)
  // ============================================================

  // Part 1: Pattern Logic
  static const int patternQuestionCount = 5; // picked randomly from the pool
  static const int patternQuestionDuration = 10; // seconds per question

  // Part 2: Sequence Recall
  static const int sequenceRoundCount = 3;
  static const int startingSequenceLength = 3; // grows by 1 every round
  static const int previewSeconds = 3;
  static const int sequenceRoundDuration = 15; // seconds per round (to repeat)

  // XP
  static const int patternXp = 10;
  static const int sequenceXp = 15;
  static const int streakBonusXp = 5; // every 3 correct in a row

  // Pass mark for the result screen
  static const double passAccuracy = 60;

  // ============================================================
  // DATA
  // ============================================================

  static const List<Map<String, dynamic>> _patternPool = [
    {
      'pattern': '2 → 4 → 6 → 8 → ?',
      'answers': ['9', '10', '11', '12'],
      'correct': '10',
    },
    {
      'pattern': '5 → 10 → 15 → 20 → ?',
      'answers': ['25', '30', '22', '24'],
      'correct': '25',
    },
    {
      'pattern': '🔴 → 🔵 → 🔴 → 🔵 → ?',
      'answers': ['🟢', '🔴', '🟡', '🔵'],
      'correct': '🔴',
    },
    {
      'pattern': '3 → 6 → 9 → 12 → ?',
      'answers': ['14', '15', '16', '18'],
      'correct': '15',
    },
    {
      'pattern': '10 → 20 → 30 → 40 → ?',
      'answers': ['45', '50', '55', '60'],
      'correct': '50',
    },
    {
      'pattern': '1 → 4 → 9 → 16 → ?',
      'answers': ['20', '24', '25', '30'],
      'correct': '25',
    },
    {
      'pattern': '100 → 90 → 80 → 70 → ?',
      'answers': ['50', '55', '60', '65'],
      'correct': '60',
    },
    {
      'pattern': '🔺 → 🔵 → 🟢 → 🔺 → 🔵 → ?',
      'answers': ['🔴', '🟢', '🟡', '🔵'],
      'correct': '🟢',
    },
    {
      'pattern': '2 → 6 → 12 → 20 → ?',
      'answers': ['24', '28', '30', '32'],
      'correct': '30',
    },
    {
      'pattern': '50 → 45 → 40 → 35 → ?',
      'answers': ['25', '30', '32', '40'],
      'correct': '30',
    },
  ];

  static const List<String> symbols = [
    '⭐',
    '🔵',
    '🔺',
    '🟩',
    '❤️',
    '🌙',
    '☀️',
    '🍎',
    '🚀',
    '🐱',
  ];

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final AudioPlayer _audioPlayer = AudioPlayer();
  late ConfettiController confettiController;
  late AnimationController _shakeController;
  Timer? timer;

  // ============================================================
  // GAME STATE
  // ============================================================

  GameStage stage = GameStage.pattern;

  // Part 1
  late List<Map<String, dynamic>> questions;
  int patternIndex = 0;
  int patternCorrect = 0;
  int patternWrong = 0;
  String? selectedAnswer;

  // Part 2
  List<String> currentSequence = [];
  List<String> playerSequence = [];
  int sequenceIndex = 0;
  int sequenceCorrect = 0;
  int sequenceWrong = 0;
  bool showingSequence = true;
  int previewTime = previewSeconds;

  // Shared
  int timeLeft = patternQuestionDuration;
  int xp = 0;
  int streak = 0;
  int bestStreak = 0;

  bool answered = false; // true while the feedback is showing
  bool isPaused = false;

  String feedbackText = '';
  bool lastAnswerCorrect = false;

  // Used to safely ignore delayed callbacks after a restart.
  int _session = 0;

  // If the game is paused while feedback is showing, the next step waits here.
  VoidCallback? _pendingAction;

  // ============================================================
  // DERIVED VALUES
  // ============================================================

  int get totalCorrect => patternCorrect + sequenceCorrect;

  int get totalAttempts =>
      patternCorrect + patternWrong + sequenceCorrect + sequenceWrong;

  double get accuracy {
    if (totalAttempts == 0) return 0;
    return (totalCorrect / totalAttempts) * 100;
  }

  bool get passed => accuracy >= passAccuracy;

  String getGrade() {
    if (accuracy >= 90) return 'S';
    if (accuracy >= 80) return 'A';
    if (accuracy >= 70) return 'B';
    if (accuracy >= 60) return 'C';
    return 'D';
  }

  // ============================================================
  // INIT / RESET
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

    _resetState();
    startPatternTimer();
  }

  void _resetState() {
    timer?.cancel();
    _session++;
    _pendingAction = null;

    questions = List<Map<String, dynamic>>.of(_patternPool)
      ..shuffle(Random());
    questions = questions.take(patternQuestionCount).toList();

    stage = GameStage.pattern;

    patternIndex = 0;
    patternCorrect = 0;
    patternWrong = 0;
    selectedAnswer = null;

    currentSequence = [];
    playerSequence = [];
    sequenceIndex = 0;
    sequenceCorrect = 0;
    sequenceWrong = 0;
    showingSequence = true;
    previewTime = previewSeconds;

    timeLeft = patternQuestionDuration;
    xp = 0;
    streak = 0;
    bestStreak = 0;

    answered = false;
    isPaused = false;

    feedbackText = '';
    lastAnswerCorrect = false;
  }

  void restartGame() {
    _audioPlayer.stop();

    setState(() {
      _resetState();
    });

    startPatternTimer();
  }

  void goToMainMenu() {
    Navigator.pop(context);
  }

  // ============================================================
  // SOUND
  // ============================================================

  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void playCorrectSound() => _playSound('correct.mp3');

  void playWrongSound() => _playSound('wrong.mp3');

  void playCompleteSound() => _playSound('level up.mp3');

  // ============================================================
  // SHARED HELPERS
  // ============================================================

  /// Call inside setState. Adds streak + XP for a correct answer.
  void _awardCorrect(int baseXp) {
    correctStreakUp();

    int earned = baseXp;
    if (streak % 3 == 0) earned += streakBonusXp;

    xp += earned;
  }

  void correctStreakUp() {
    streak++;
    if (streak > bestStreak) bestStreak = streak;
  }

  /// Runs [action] after a short pause. If the game is paused when the pause
  /// ends, the action waits until the player resumes.
  void _scheduleAdvance(VoidCallback action) {
    final int session = _session;

    Future.delayed(
      const Duration(milliseconds: 900),
      () {
        if (!mounted) return;
        if (session != _session) return;

        if (isPaused) {
          _pendingAction = action;
          return;
        }

        action();
      },
    );
  }

  void _startCountdown(VoidCallback onTimeout) {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        if (isPaused) return;

        if (timeLeft <= 1) {
          t.cancel();

          setState(() {
            timeLeft = 0;
          });

          onTimeout();
        } else {
          setState(() {
            timeLeft--;
          });
        }
      },
    );
  }

  // ============================================================
  // PAUSE / RESUME
  // ============================================================

  void pauseGame() {
    if (isPaused) return;
    if (stage != GameStage.pattern && stage != GameStage.sequence) return;

    timer?.cancel();
    _audioPlayer.pause();

    setState(() {
      isPaused = true;
    });
  }

  void resumeGame() {
    if (!isPaused) return;

    setState(() {
      isPaused = false;
    });

    _audioPlayer.resume();

    // Paused while feedback was showing: continue to the next step.
    if (_pendingAction != null) {
      final action = _pendingAction!;
      _pendingAction = null;
      action();
      return;
    }

    // Feedback still on screen: its scheduled step will fire by itself.
    if (answered) return;

    if (stage == GameStage.pattern) {
      startPatternTimer(reset: false);
    } else if (stage == GameStage.sequence) {
      if (showingSequence) {
        startPreview();
      } else {
        startSequenceTimer(reset: false);
      }
    }
  }

  // ============================================================
  // PART 1: PATTERN LOGIC
  // ============================================================

  void startPatternTimer({bool reset = true}) {
    if (reset) timeLeft = patternQuestionDuration;

    _startCountdown(handlePatternTimeout);
  }

  void handlePatternTimeout() {
    if (answered || isPaused || stage != GameStage.pattern) return;

    final String correct = questions[patternIndex]['correct'] as String;

    setState(() {
      answered = true;
      selectedAnswer = null;

      patternWrong++;
      streak = 0;

      feedbackText = "Time's up! ❌ Correct: $correct";
      lastAnswerCorrect = false;
    });

    _shakeController.forward(from: 0.0);
    playWrongSound();

    _scheduleAdvance(nextPatternQuestion);
  }

  void checkPatternAnswer(String answer) {
    if (answered || isPaused || stage != GameStage.pattern) return;

    timer?.cancel();

    final String correct = questions[patternIndex]['correct'] as String;
    final bool isCorrect = answer == correct;

    setState(() {
      answered = true;
      selectedAnswer = answer;

      if (isCorrect) {
        patternCorrect++;
        _awardCorrect(patternXp);

        feedbackText = 'Correct! ✔';
        lastAnswerCorrect = true;
      } else {
        patternWrong++;
        streak = 0;

        feedbackText = 'Wrong! ❌ Correct: $correct';
        lastAnswerCorrect = false;
      }
    });

    if (isCorrect) {
      playCorrectSound();
    } else {
      _shakeController.forward(from: 0.0);
      playWrongSound();
    }

    _scheduleAdvance(nextPatternQuestion);
  }

  void nextPatternQuestion() {
    if (!mounted || isPaused) return;

    // Part 1 finished -> show the intro for Part 2.
    if (patternIndex >= questions.length - 1) {
      setState(() {
        stage = GameStage.intro;
        answered = false;
        selectedAnswer = null;
        feedbackText = '';
      });
      return;
    }

    setState(() {
      patternIndex++;
      answered = false;
      selectedAnswer = null;
      feedbackText = '';
    });

    startPatternTimer();
  }

  // ============================================================
  // PART 2: SEQUENCE RECALL
  // ============================================================

  void startSequencePart() {
    setState(() {
      stage = GameStage.sequence;
      sequenceIndex = 0;
      _prepareRound();
    });

    startPreview();
  }

  /// Call inside setState.
  void _prepareRound() {
    final int length = startingSequenceLength + sequenceIndex;
    final Random random = Random();

    currentSequence = [];

    while (currentSequence.length < length) {
      final String symbol = symbols[random.nextInt(symbols.length)];

      // Never repeat the same symbol twice in a row.
      if (currentSequence.isEmpty || currentSequence.last != symbol) {
        currentSequence.add(symbol);
      }
    }

    playerSequence = [];
    showingSequence = true;
    previewTime = previewSeconds;
    timeLeft = sequenceRoundDuration;

    answered = false;
    feedbackText = '';
    lastAnswerCorrect = false;
  }

  void startPreview() {
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
          previewTime--;
        });

        if (previewTime <= 0) {
          t.cancel();

          setState(() {
            showingSequence = false;
            timeLeft = sequenceRoundDuration;
          });

          startSequenceTimer(reset: false);
        }
      },
    );
  }

  void startSequenceTimer({bool reset = true}) {
    if (reset) timeLeft = sequenceRoundDuration;

    _startCountdown(handleSequenceTimeout);
  }

  void handleSequenceTimeout() {
    if (answered || isPaused || stage != GameStage.sequence) return;

    setState(() {
      answered = true;

      sequenceWrong++;
      streak = 0;

      feedbackText = "Time's up! ❌ ${currentSequence.join(' ')}";
      lastAnswerCorrect = false;
    });

    _shakeController.forward(from: 0.0);
    playWrongSound();

    _scheduleAdvance(nextSequenceRound);
  }

  void selectSymbol(String symbol) {
    if (stage != GameStage.sequence ||
        showingSequence ||
        answered ||
        isPaused) {
      return;
    }

    if (playerSequence.length >= currentSequence.length) return;

    setState(() {
      playerSequence.add(symbol);
    });

    if (playerSequence.length == currentSequence.length) {
      checkSequenceAnswer();
    }
  }

  /// Tap a placed symbol to take it back out of the player's sequence.
  /// The symbols after it move back one slot to fill the gap.
  void removeSymbolAt(int index) {
    if (stage != GameStage.sequence ||
        showingSequence ||
        answered ||
        isPaused) {
      return;
    }

    if (index < 0 || index >= playerSequence.length) return;

    setState(() {
      playerSequence.removeAt(index);
    });
  }

  void checkSequenceAnswer() {
    if (answered) return;

    timer?.cancel();

    final bool isCorrect = currentSequence.join(',') == playerSequence.join(',');

    setState(() {
      answered = true;

      if (isCorrect) {
        sequenceCorrect++;
        _awardCorrect(sequenceXp);

        feedbackText = 'Correct! ✔';
        lastAnswerCorrect = true;
      } else {
        sequenceWrong++;
        streak = 0;

        feedbackText = 'Wrong! ❌ ${currentSequence.join(' ')}';
        lastAnswerCorrect = false;
      }
    });

    if (isCorrect) {
      playCorrectSound();
    } else {
      _shakeController.forward(from: 0.0);
      playWrongSound();
    }

    _scheduleAdvance(nextSequenceRound);
  }

  void nextSequenceRound() {
    if (!mounted || isPaused) return;

    if (sequenceIndex >= sequenceRoundCount - 1) {
      finishGame();
      return;
    }

    setState(() {
      sequenceIndex++;
      _prepareRound();
    });

    startPreview();
  }

  // ============================================================
  // FINISH + SAVE
  // ============================================================

  void finishGame() {
    timer?.cancel();

    setState(() {
      stage = GameStage.result;
      isPaused = false;
      answered = false;
    });

    if (passed) {
      confettiController.play();
      playCompleteSound();
    }

    saveScore();
  }

  Future<void> saveScore() async {
    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Pattern & Sequence',
        'patternCorrect': patternCorrect,
        'patternTotal': questions.length,
        'sequenceCorrect': sequenceCorrect,
        'sequenceTotal': sequenceRoundCount,
        'correct': totalCorrect,
        'wrong': patternWrong + sequenceWrong,
        'accuracy': accuracy,
        'xp': xp,
        'streak': bestStreak,
        'grade': getGrade(),
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error saving Pattern & Sequence score: $e');
    }
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================

  Widget _glassCard({
    required Widget child,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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

  Widget _buildCustomAppBar() {
    final bool showPause =
        stage == GameStage.pattern || stage == GameStage.sequence;

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
                'Pattern & Sequence',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (showPause)
              IconButton(
                onPressed: pauseGame,
                icon: const Icon(
                  Icons.pause_circle_filled,
                  color: Colors.amber,
                  size: 32,
                ),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GAMEPLAY (shared HUD + per-stage content)
  // ============================================================

  Widget _buildGameplay() {
    final bool isPattern = stage == GameStage.pattern;
    final bool previewing = !isPattern && showingSequence;

    final int displayTime = previewing ? previewTime : timeLeft;

    final int totalTime = isPattern
        ? patternQuestionDuration
        : (previewing ? previewSeconds : sequenceRoundDuration);

    final bool lowTime = !previewing && displayTime <= 3;

    final Color timeColor = previewing
        ? Colors.amber
        : (lowTime ? Colors.redAccent : Colors.cyanAccent);

    final String stageLabel = isPattern
        ? 'PART 1 · QUESTION ${patternIndex + 1}/${questions.length}'
        : 'PART 2 · ROUND ${sequenceIndex + 1}/$sequenceRoundCount';

    final String instruction;
    if (isPattern) {
      instruction = answered
          ? 'Get ready for the next one...'
          : 'Pick the answer that continues the pattern';
    } else if (previewing) {
      instruction = 'Remember the symbols in order';
    } else {
      instruction = answered
          ? 'Get ready for the next round...'
          : 'Tap symbols in order · tap a placed one to remove it';
    }

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
                  value: '${displayTime}s',
                  valueColor: timeColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.star_rounded,
                  title: 'XP',
                  value: '$xp',
                  valueColor: Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.local_fire_department,
                  title: 'STREAK',
                  value: '$streak',
                  valueColor: Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHudCard(
                  icon: Icons.emoji_events_rounded,
                  title: 'BEST',
                  value: '$bestStreak',
                  valueColor: Colors.purpleAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Content (scrolls only on very small screens)
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stageLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isPattern
                              ? Colors.cyanAccent
                              : const Color(0xFFFFD700),
                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Timer bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (displayTime / totalTime).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(timeColor),
                        ),
                      ),

                      const SizedBox(height: 14),

                      if (isPattern)
                        ..._buildPatternContent()
                      else
                        ..._buildSequenceContent(previewing),

                      const SizedBox(height: 16),

                      // Feedback (fixed height so nothing jumps)
                      SizedBox(
                        height: 28,
                        child: feedbackText.isEmpty
                            ? null
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  feedbackText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: lastAnswerCorrect
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Instruction
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              instruction,
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

  // ------------------------------------------------------------
  // Part 1 content
  // ------------------------------------------------------------

  List<Widget> _buildPatternContent() {
    final current = questions[patternIndex];
    final String pattern = current['pattern'] as String;
    final List<dynamic> answers = current['answers'] as List<dynamic>;

    return [
      _glassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Text(
          pattern,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 20),
      GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.0,
        ),
        itemCount: answers.length,
        itemBuilder: (context, index) {
          return _buildAnswerButton(answers[index].toString());
        },
      ),
    ];
  }

  Widget _buildAnswerButton(String answer) {
    final String correct = questions[patternIndex]['correct'] as String;

    final bool isCorrectAnswer = answer == correct;
    final bool isSelected = selectedAnswer == answer;

    List<Color> colors = const [
      Color(0xFF6A1B9A),
      Color(0xFF3949AB),
    ];

    double opacity = 1.0;

    if (answered) {
      if (isCorrectAnswer) {
        colors = const [
          Color(0xFF2E7D32),
          Color(0xFF43A047),
        ];
      } else if (isSelected) {
        colors = const [
          Color(0xFFC62828),
          Color(0xFFE53935),
        ];
      } else {
        opacity = 0.4;
      }
    }

    return GestureDetector(
      onTap: (answered || isPaused) ? null : () => checkPatternAnswer(answer),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: answered && isCorrectAnswer
                  ? Colors.greenAccent
                  : Colors.white24,
              width: answered && isCorrectAnswer ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  answer,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Part 2 content
  // ------------------------------------------------------------

  List<Widget> _buildSequenceContent(bool previewing) {
    if (previewing) {
      return [
        const Text(
          'MEMORIZE THE SEQUENCE',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.amber,
            letterSpacing: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildSequenceDisplay(),
      ];
    }

    return [
      const Text(
        'REPEAT THE SEQUENCE',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.amber,
          letterSpacing: 1.1,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      const Text(
        'YOUR SEQUENCE',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 8),
      _buildPlayerSequence(),
      const SizedBox(height: 20),
      const Text(
        'CHOOSE SYMBOLS',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: symbols.map(_buildSymbolButton).toList(),
      ),
    ];
  }

  Widget _buildSequenceDisplay() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: currentSequence.map((symbol) {
        return Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                offset: Offset(0, 4),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(symbol, style: const TextStyle(fontSize: 32)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerSequence() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(currentSequence.length, (index) {
        final bool hasValue = index < playerSequence.length;

        return GestureDetector(
          onTap: hasValue ? () => removeSymbolAt(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: hasValue
                  ? const Color(0xFFFF4081)
                  : Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue ? Colors.white : Colors.white38,
                width: 2,
              ),
              boxShadow: hasValue
                  ? const [
                      BoxShadow(
                        color: Color(0xFF990033),
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                hasValue ? playerSequence[index] : '?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: hasValue ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSymbolButton(String symbol) {
    final bool disabled = answered || isPaused;

    return GestureDetector(
      onTap: disabled ? null : () => selectSymbol(symbol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: disabled ? Colors.white.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled ? Colors.white24 : const Color(0xFFFFD700),
            width: 2,
          ),
          boxShadow: disabled
              ? null
              : const [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, 4),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 28,
              color: disabled ? Colors.white38 : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INTRO SCREEN (between Part 1 and Part 2)
  // ============================================================

  Widget _buildIntroScreen() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: _glassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '✅ PART 1 COMPLETE!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Patterns solved: $patternCorrect/${questions.length}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              const Text(
                '🧠 PART 2: SEQUENCE RECALL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.cyanAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Memorize the symbols, then tap them back in the same order.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              _buildChunkyButton(
                label: 'Start Part 2',
                icon: Icons.arrow_forward_rounded,
                color: const Color(0xFFFF9F1C),
                onPressed: startSequencePart,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESULT SCREEN (same style as Science Puzzle)
  // ============================================================

  Widget _buildResultScreen() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: _glassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                passed ? '🎉 LEVEL COMPLETE!' : '😅 KEEP PRACTICING!',
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
                    ? 'Great job spotting patterns and remembering sequences!'
                    : 'Not quite enough correct answers. Try again!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // GRADE PILL
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

              // MAIN STATS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBadge('⭐ XP', '+$xp'),
                  _buildStatBadge(
                      '🎯 Accuracy', '${accuracy.toStringAsFixed(0)}%'),
                  _buildStatBadge('🔥 Best', '$bestStreak'),
                ],
              ),
              const SizedBox(height: 14),

              // PER-PART BREAKDOWN
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBadge(
                      '🧩 Patterns', '$patternCorrect/${questions.length}'),
                  _buildStatBadge(
                      '🧠 Sequences', '$sequenceCorrect/$sequenceRoundCount'),
                ],
              ),
              const SizedBox(height: 20),

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
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  Widget _buildBody() {
    switch (stage) {
      case GameStage.pattern:
      case GameStage.sequence:
        return _buildGameplay();
      case GameStage.intro:
        return _buildIntroScreen();
      case GameStage.result:
        return _buildResultScreen();
    }
  }

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
                    animation: _shakeController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          sin(_shakeController.value * pi * 6) *
                              8 *
                              (1 - _shakeController.value),
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: _buildBody(),
                  ),
                ),
              ],
            ),

            // Pause menu
            if (isPaused)
              Positioned.fill(
                child: PauseMenu(
                  onResume: resumeGame,
                  onRestart: restartGame,
                  onOptions: () {},
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
    _session++;

    timer?.cancel();
    confettiController.dispose();
    _audioPlayer.dispose();
    _shakeController.dispose();

    super.dispose();
  }
}