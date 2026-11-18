import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../services/score_identity.dart';
import '../models/game_difficulty.dart';
import '../services/game_audio.dart';
import '../services/game_options_menu.dart';
import '../widgets/pause_menu.dart';
import 'memory_match.dart';
import 'tile_matrix.dart';

class PatternSequence extends StatefulWidget {
  final GameDifficulty difficulty;

  const PatternSequence({
    super.key,
    this.difficulty = GameDifficulty.hard,
  });

  @override
  State<PatternSequence> createState() => _PatternSequenceState();
}

class _PatternSequenceState extends State<PatternSequence>
    with TickerProviderStateMixin {
  // ============================================================
  // DIFFICULTY SETTINGS
  // ============================================================

  int get patternQuestionCount {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 5;
      case GameDifficulty.medium:
        return 7;
      case GameDifficulty.hard:
        return 10;
    }
  }

  int get patternQuestionDuration {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return 0;
      case GameDifficulty.medium:
        return 15;
      case GameDifficulty.hard:
        return 10;
    }
  }

  bool get hasTimer => widget.difficulty != GameDifficulty.easy;

  static const int patternXp = 10;
  static const int streakBonusXp = 5;
  static const double passAccuracy = 60;

  static const List<Map<String, dynamic>> _patternPool = [
    {'pattern': '2 → 4 → 6 → 8 → ?', 'answers': ['9', '10', '11', '12'], 'correct': '10'},
    {'pattern': '5 → 10 → 15 → 20 → ?', 'answers': ['25', '30', '22', '24'], 'correct': '25'},
    {'pattern': '🔴 → 🔵 → 🔴 → 🔵 → ?', 'answers': ['🟢', '🔴', '🟡', '🔵'], 'correct': '🔴'},
    {'pattern': '3 → 6 → 9 → 12 → ?', 'answers': ['14', '15', '16', '18'], 'correct': '15'},
    {'pattern': '10 → 20 → 30 → 40 → ?', 'answers': ['45', '50', '55', '60'], 'correct': '50'},
    {'pattern': '1 → 4 → 9 → 16 → ?', 'answers': ['20', '24', '25', '30'], 'correct': '25'},
    {'pattern': '100 → 90 → 80 → 70 → ?', 'answers': ['50', '55', '60', '65'], 'correct': '60'},
    {'pattern': '🔺 → 🔵 → 🟢 → 🔺 → 🔵 → ?', 'answers': ['🔴', '🟢', '🟡', '🔵'], 'correct': '🟢'},
    {'pattern': '2 → 6 → 12 → 20 → ?', 'answers': ['24', '28', '30', '32'], 'correct': '30'},
    {'pattern': '50 → 45 → 40 → 35 → ?', 'answers': ['25', '30', '32', '40'], 'correct': '30'},
  ];

  // Shared audio controller, with this game's own music.
  final GameAudio audio = GameAudio(
    musicAsset: 'sounds/The_Seventh_Variable.mp3',
  );

  late ConfettiController confettiController;
  late AnimationController _shakeController;
  Timer? timer;

  late List<Map<String, dynamic>> questions;
  int patternIndex = 0;
  int patternCorrect = 0;
  int patternWrong = 0;
  String? selectedAnswer;
  int timeLeft = 0;
  int xp = 0;
  int streak = 0;
  int bestStreak = 0;

  bool answered = false;
  bool isPaused = false;
  bool gameEnded = false;
  bool showOptions = false;

  String feedbackText = '';
  bool lastAnswerCorrect = false;
  int _session = 0;

  // Progress message shown on the result screen (null while loading).
  _ProgressMessage? progressMessage;

  int get totalCorrect => patternCorrect;
  int get totalAttempts => patternCorrect + patternWrong;
  double get accuracy =>
      totalAttempts == 0 ? 0 : totalCorrect / totalAttempts * 100;
  bool get passed => accuracy >= passAccuracy;

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
    confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _resetState();
    _initAudio();
    if (hasTimer) startPatternTimer();
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

  void _resetState() {
    timer?.cancel();
    _session++;

    // Make sure the screen is back at its normal position.
    _shakeController.reset();
    confettiController.stop();

    questions = List<Map<String, dynamic>>.of(_patternPool)..shuffle(Random());
    questions = questions.take(patternQuestionCount).toList();
    patternIndex = 0;
    patternCorrect = 0;
    patternWrong = 0;
    selectedAnswer = null;
    timeLeft = hasTimer ? patternQuestionDuration : 0;
    xp = 0;
    streak = 0;
    bestStreak = 0;
    answered = false;
    isPaused = false;
    gameEnded = false;
    showOptions = false;
    feedbackText = '';
    lastAnswerCorrect = false;
    progressMessage = null;
  }

  void restartGame() {
    timer?.cancel();
    setState(_resetState);
    audio.stopEffects();
    audio.startMusic();
    if (hasTimer) startPatternTimer();
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void goToMainMenu() => Navigator.pop(context);

  // PREVIOUS LEVEL → Level 3: Memory Match (same difficulty)
  void goToPreviousLevel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryMatch(
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  // NEXT LEVEL → Level 5: Tile Matrix (same difficulty)
  void goToNextLevel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryMatrix(
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  void _awardCorrect() {
    streak++;
    if (streak > bestStreak) bestStreak = streak;
    xp += patternXp + (streak % 3 == 0 ? streakBonusXp : 0);
  }

  void _scheduleAdvance(VoidCallback action) {
    final int session = _session;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || session != _session) return;
      if (isPaused) return;
      action();
    });
  }

  void _startCountdown(VoidCallback onTimeout) {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (isPaused || answered) return;
      if (timeLeft <= 1) {
        t.cancel();
        setState(() => timeLeft = 0);
        onTimeout();
      } else {
        setState(() => timeLeft--);
      }
    });
  }

  void startPatternTimer({bool reset = true}) {
    if (!hasTimer) {
      timer?.cancel();
      timeLeft = 0;
      return;
    }

    if (reset) timeLeft = patternQuestionDuration;
    _startCountdown(handlePatternTimeout);
  }

  void handlePatternTimeout() {
    if (answered || isPaused || gameEnded) return;
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
    audio.playWrong();
    _scheduleAdvance(nextPatternQuestion);
  }

  void checkPatternAnswer(String answer) {
    if (answered || isPaused || gameEnded) return;
    timer?.cancel();
    final String correct = questions[patternIndex]['correct'] as String;
    final bool isCorrect = answer == correct;
    setState(() {
      answered = true;
      selectedAnswer = answer;
      if (isCorrect) {
        patternCorrect++;
        _awardCorrect();
        feedbackText = 'Correct! ✔';
        lastAnswerCorrect = true;
      } else {
        patternWrong++;
        streak = 0;
        feedbackText = 'Wrong! ❌ Correct: $correct';
        lastAnswerCorrect = false;
      }
    });
    // Trigger the sound immediately when the answer is evaluated.
    if (isCorrect) {
      audio.playCorrect();
    } else {
      _shakeController.forward(from: 0.0);
      audio.playWrong();
    }
    _scheduleAdvance(nextPatternQuestion);
  }

  void nextPatternQuestion() {
    if (!mounted || isPaused || gameEnded) return;
    if (patternIndex >= questions.length - 1) {
      finishGame();
      return;
    }
    setState(() {
      patternIndex++;
      answered = false;
      selectedAnswer = null;
      feedbackText = '';
      timeLeft = hasTimer ? patternQuestionDuration : 0;
    });
    startPatternTimer();
  }

  void pauseGame() {
    if (isPaused || gameEnded) return;
    timer?.cancel();
    audio.pauseAll();
    setState(() {
      isPaused = true;
      showOptions = false;
    });
  }

  Future<void> resumeGame() async {
    if (!isPaused || gameEnded) return;
    setState(() {
      isPaused = false;
      showOptions = false;
    });
    await audio.resume();
    if (!mounted) return;
    if (answered) return;
    startPatternTimer(reset: false);
  }

  void finishGame() {
    if (gameEnded) return;
    timer?.cancel();
    setState(() {
      gameEnded = true;
      isPaused = false;
      showOptions = false;
    });
    audio.stopMusic();
    if (passed) {
      confettiController.play();
      audio.playComplete();
    }
    saveScore();
  }

  Future<void> saveScore() async {
    try {
      // Get the current player's identity.
      final identityFields = await ScoreIdentity.fields();

      // Compare against past games BEFORE saving this one, so the
      // current game isn't compared with itself.
      await _evaluateProgress(identityFields);

      final scoreReference =
          await FirebaseFirestore.instance.collection('scores').add({
        // Shared player identity
        ...identityFields,

        // Level information
        'level': 4,
        'levelName': 'Pattern Logic',
        'difficulty': widget.difficulty.label,

        // Game results
        'patternCorrect': patternCorrect,
        'patternTotal': questions.length,
        'correct': patternCorrect,
        'wrong': patternWrong,
        'accuracy': accuracy,
        'xp': xp,
        'streak': bestStreak,
        'grade': getGrade(),
        'completed': passed,

        // Timestamp
        'timestamp': FieldValue.serverTimestamp(),
      });
      await ScoreIdentity.recordRecentGame(scoreReference);

      debugPrint('Pattern Logic score saved successfully.');
    } catch (e) {
      debugPrint('Error saving Pattern Logic score: $e');
    }
  }

  // ============================================================
  // PROGRESS COMPARISON
  // (uses the same playedGameHistory as game_history.dart)
  // ============================================================

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
        .get();

    final raw = doc.data()?['playedGameHistory'];
    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((g) =>
            (g['levelName'] ?? g['gameName'] ?? g['game']) ==
                'Pattern Logic' &&
            g['difficulty'] == widget.difficulty.label)
        .toList(); // oldest -> newest (same order the history screen uses)
  }

  Future<void> _evaluateProgress(Map<String, dynamic> identityFields) async {
    List<Map<String, dynamic>> previous = [];
    try {
      previous = await _loadPreviousGames(identityFields);
    } catch (e) {
      debugPrint('Could not load history: $e');
    }

    final message = _buildProgressMessage(previous);
    if (!mounted) return;
    setState(() => progressMessage = message);
  }

  _ProgressMessage _buildProgressMessage(List<Map<String, dynamic>> previous) {
    int accOf(Map<String, dynamic> g) =>
        (g['accuracy'] as num?)?.round() ?? 0;
    int xpOf(Map<String, dynamic> g) => (g['xp'] as num?)?.round() ?? 0;
    int streakOf(Map<String, dynamic> g) =>
        (g['streak'] as num?)?.round() ?? 0;

    final currentAcc = accuracy.round();
    final grade = getGrade();
    final total = questions.length;

    // ---------- FIRST GAME ON THIS DIFFICULTY ----------
    if (previous.isEmpty) {
      if (passed) {
        return _ProgressMessage(
          title: 'FIRST CLEAR!',
          detail: 'You earned a grade $grade with $currentAcc% accuracy. '
              'That\'s your starting mark — can you beat it?',
          icon: Icons.flag_rounded,
          color: Colors.amber,
        );
      }
      return _ProgressMessage(
        title: 'GOOD TRY!',
        detail: 'You got $patternCorrect/$total right. You need '
            '${passAccuracy.round()}% to pass — look closely at how each '
            'pattern changes and try again!',
        icon: Icons.refresh_rounded,
        color: Colors.orangeAccent,
      );
    }

    final bestAcc = previous.map(accOf).reduce(max);
    final bestXp = previous.map(xpOf).reduce(max);
    final bestPrevStreak = previous.map(streakOf).reduce(max);
    final lastAcc = accOf(previous.last);

    final streakNote = (bestStreak >= 3 && bestStreak > bestPrevStreak)
        ? ' Longest streak yet: $bestStreak!'
        : '';

    // ---------- DID NOT PASS ----------
    if (!passed) {
      if (currentAcc > lastAcc) {
        return _ProgressMessage(
          title: 'GETTING BETTER!',
          detail: '+${currentAcc - lastAcc}% over your last game, but you '
              'need ${passAccuracy.round()}% to pass. Your best is $bestAcc%.',
          icon: Icons.trending_up_rounded,
          color: Colors.cyanAccent,
        );
      }
      return _ProgressMessage(
        title: 'KEEP PRACTICING!',
        detail: 'You scored $currentAcc% (your best is $bestAcc%). '
            'Look at the gap between each item to find the rule.',
        icon: Icons.refresh_rounded,
        color: Colors.redAccent,
      );
    }

    // ---------- NEW PERSONAL BEST ----------
    if (currentAcc > bestAcc) {
      return _ProgressMessage(
        title: grade == 'S' ? 'PERFECT & A NEW BEST!' : 'NEW PERSONAL BEST!',
        detail: '+${currentAcc - bestAcc}% accuracy over your previous best '
            '($bestAcc%).$streakNote',
        icon: Icons.emoji_events_rounded,
        color: Colors.amber,
      );
    }

    // ---------- MATCHED BEST ACCURACY ----------
    if (currentAcc == bestAcc) {
      if (xp > bestXp) {
        return _ProgressMessage(
          title: 'SAME ACCURACY, MORE XP!',
          detail: 'You matched your best accuracy ($bestAcc%) and earned '
              '${xp - bestXp} more XP than ever before.$streakNote',
          icon: Icons.stars_rounded,
          color: Colors.amber,
        );
      }
      return _ProgressMessage(
        title: 'MATCHED YOUR BEST!',
        detail: grade == 'S'
            ? 'Still flawless — you\'re at the top of your game.$streakNote'
            : 'You tied your best accuracy ($bestAcc%). '
                'One more correct answer could beat it!$streakNote',
        icon: Icons.equalizer_rounded,
        color: Colors.lightGreenAccent,
      );
    }

    // ---------- BETTER THAN LAST GAME ----------
    if (currentAcc > lastAcc) {
      return _ProgressMessage(
        title: 'YOU\'RE IMPROVING!',
        detail: '+${currentAcc - lastAcc}% compared to your last game. '
            'Your best is $bestAcc%.$streakNote',
        icon: Icons.trending_up_rounded,
        color: Colors.cyanAccent,
      );
    }

    // ---------- WORSE THAN BEFORE ----------
    final gap = bestAcc - currentAcc;
    final tip = patternWrong == 1
        ? 'You missed just 1 question — double-check the pattern before '
            'answering.'
        : 'You missed $patternWrong questions — look closely at how each '
            'pattern changes.';
    return _ProgressMessage(
      title: grade == 'S' || grade == 'A'
          ? 'GREAT, BUT NOT YOUR BEST'
          : 'NOT YOUR BEST YET',
      detail: '$gap% below your best ($bestAcc%). $tip',
      icon: Icons.trending_down_rounded,
      color: Colors.orangeAccent,
    );
  }

  // ============================================================
  // UI HELPERS
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
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
                    'LEVEL 4: PATTERN SEQUENCE',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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
            if (!gameEnded)
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

  Widget _buildGameplay() {
    final int displayTime = timeLeft;
    final bool lowTime = displayTime <= 3;
    final Color timeColor = lowTime ? Colors.redAccent : Colors.cyanAccent;
    final current = questions[patternIndex];
    final String pattern = current['pattern'] as String;
    final answers = (current['answers'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              if (hasTimer) ...[
                Expanded(
                  child: _buildHudCard(
                    icon: Icons.timer_outlined,
                    title: 'TIME',
                    value: '${displayTime}s',
                    valueColor: timeColor,
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
                        'QUESTION ${patternIndex + 1}/${questions.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.cyanAccent,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (hasTimer) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (displayTime / patternQuestionDuration)
                                .clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(timeColor),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _glassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 28,
                        ),
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.0,
                        ),
                        itemCount: answers.length,
                        itemBuilder: (context, index) =>
                            _buildAnswerButton(answers[index].toString()),
                      ),
                      const SizedBox(height: 16),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              answered
                  ? 'Get ready for the next question...'
                  : 'Pick the answer that continues the pattern',
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

  Widget _buildAnswerButton(String answer) {
    final String correct = questions[patternIndex]['correct'] as String;
    final bool isCorrectAnswer = answer == correct;
    final bool isSelected = selectedAnswer == answer;
    List<Color> colors = const [Color(0xFF6A1B9A), Color(0xFF3949AB)];
    double opacity = 1.0;

    if (answered) {
      if (isCorrectAnswer) {
        colors = const [Color(0xFF2E7D32), Color(0xFF43A047)];
      } else if (isSelected) {
        colors = const [Color(0xFFC62828), Color(0xFFE53935)];
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

  // PROGRESS CARD (result screen)
  Widget _buildProgressCard() {
    final message = progressMessage;

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

  Widget _buildResultScreen() {
    return Center(
      child: SingleChildScrollView(
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
              const SizedBox(height: 10),

              // Progress message based on the player's history
              _buildProgressCard(),

              const SizedBox(height: 16),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBadge('⭐ XP', '+$xp'),
                  _buildStatBadge(
                    '🎯 Accuracy',
                    '${accuracy.toStringAsFixed(0)}%',
                  ),
                  _buildStatBadge('🔥 Best', '$bestStreak'),
                ],
              ),
              const SizedBox(height: 14),
              _buildStatBadge(
                '🧩 Correct Answers',
                '$patternCorrect/${questions.length}',
              ),
              const SizedBox(height: 20),

              // Try Again
              _buildChunkyButton(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                color: const Color(0xFF2EC4B6),
                onPressed: restartGame,
              ),
              const SizedBox(height: 10),

              // Previous + Next side by side (same difficulty)
              Row(
                children: [
                  Expanded(
                    child: _buildChunkyButton(
                      label: 'Previous',
                      icon: Icons.arrow_back_rounded,
                      color: const Color(0xFF9B8AD6),
                      onPressed: goToPreviousLevel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildChunkyButton(
                      label: 'Next',
                      icon: Icons.arrow_forward_rounded,
                      color: const Color(0xFFFFD700),
                      onPressed: goToNextLevel,
                      iconAfterText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Main Menu
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
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                        sin(_shakeController.value * pi * 6) *
                            8 *
                            (1 - _shakeController.value),
                        0,
                      ),
                      child: child,
                    ),
                    child:
                        gameEnded ? _buildResultScreen() : _buildGameplay(),
                  ),
                ),
              ],
            ),

            // Pause menu + shared options screen
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

  @override
  void dispose() {
    _session++;
    timer?.cancel();
    confettiController.dispose();
    audio.dispose();
    _shakeController.dispose();
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