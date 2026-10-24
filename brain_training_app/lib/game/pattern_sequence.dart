import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../widgets/pause_menu.dart';

class PatternSequence extends StatefulWidget {
  const PatternSequence({super.key});

  @override
  State<PatternSequence> createState() => _PatternSequenceState();
}

class _PatternSequenceState extends State<PatternSequence>
    with TickerProviderStateMixin {
  static const int patternQuestionCount = 5;
  static const int patternQuestionDuration = 10;
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

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  late ConfettiController confettiController;
  late AnimationController _shakeController;
  Timer? timer;

  late List<Map<String, dynamic>> questions;
  int patternIndex = 0;
  int patternCorrect = 0;
  int patternWrong = 0;
  String? selectedAnswer;
  int timeLeft = patternQuestionDuration;
  int xp = 0;
  int streak = 0;
  int bestStreak = 0;

  bool answered = false;
  bool isPaused = false;
  bool gameEnded = false;
  bool showOptions = false;

  double musicVolume = 0.5;
  double soundVolume = 0.5;
  bool _musicStoppedForMute = false;
  String feedbackText = '';
  bool lastAnswerCorrect = false;
  int _session = 0;

  int get totalCorrect => patternCorrect;
  int get totalAttempts => patternCorrect + patternWrong;
  double get accuracy => totalAttempts == 0 ? 0 : totalCorrect / totalAttempts * 100;
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
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _resetState();
    _initAudio();
    startPatternTimer();
  }

  Future<void> _initAudio() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(musicVolume);
      if (musicVolume > 0 && mounted && !isPaused && !gameEnded) {
        await _musicPlayer.play(AssetSource('sounds/The_Seventh_Variable.mp3'));
      }
    } catch (e) {
      debugPrint('Background music error: $e');
    }
  }

  Future<void> _startBackgroundMusic() async {
    if (!mounted || isPaused || gameEnded || musicVolume <= 0) return;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(musicVolume);
      await _musicPlayer.resume();
      if (_musicStoppedForMute) {
        await _musicPlayer.play(AssetSource('sounds/Bouncing_Thoughts.mp3'), volume: musicVolume);
        _musicStoppedForMute = false;
      }
    } catch (e) {
      debugPrint('Background music error: $e');
    }
  }

  Future<void> changeMusicVolume(double value) async {
    setState(() => musicVolume = value);
    try {
      await _musicPlayer.setVolume(value);
      if (value <= 0) {
        await _musicPlayer.stop();
        _musicStoppedForMute = true;
      } else if (!isPaused && !gameEnded) {
        if (_musicStoppedForMute) {
          await _musicPlayer.play(AssetSource('sounds/Bouncing_Thoughts.mp3'), volume: value);
          _musicStoppedForMute = false;
        } else {
          await _musicPlayer.setVolume(value);
        }
      }
    } catch (e) {
      debugPrint('Music volume error: $e');
    }
  }

  Future<void> changeSoundVolume(double value) async {
    setState(() => soundVolume = value);
    try {
      await _sfxPlayer.setVolume(value);
    } catch (e) {
      debugPrint('Sound volume error: $e');
    }
  }

  void showGameOptions() {
    setState(() => showOptions = true);
  }

  void _resetState() {
    timer?.cancel();
    _session++;
    questions = List<Map<String, dynamic>>.of(_patternPool)..shuffle(Random());
    questions = questions.take(patternQuestionCount).toList();
    patternIndex = 0;
    patternCorrect = 0;
    patternWrong = 0;
    selectedAnswer = null;
    timeLeft = patternQuestionDuration;
    xp = 0;
    streak = 0;
    bestStreak = 0;
    answered = false;
    isPaused = false;
    gameEnded = false;
    showOptions = false;
    feedbackText = '';
    lastAnswerCorrect = false;
  }

  void restartGame() {
    timer?.cancel();
    _sfxPlayer.stop();
    _musicStoppedForMute = true;
    setState(_resetState);
    _startBackgroundMusic();
    startPatternTimer();
  }

  void goToMainMenu() => Navigator.pop(context);

  Future<void> _playSound(String fileName) async {
    if (soundVolume <= 0) return;
    try {
      // Do not await stop(): it introduces avoidable latency before the effect.
      _sfxPlayer.setVolume(soundVolume);
      await _sfxPlayer.play(AssetSource('sounds/$fileName'), volume: soundVolume);
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void playCorrectSound() => _playSound('correct.mp3');
  void playWrongSound() => _playSound('wrong.mp3');
  void playCompleteSound() => _playSound('level up.mp3');

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
    playWrongSound();
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
      playCorrectSound();
    } else {
      _shakeController.forward(from: 0.0);
      playWrongSound();
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
      timeLeft = patternQuestionDuration;
    });
    startPatternTimer();
  }

  void pauseGame() {
    if (isPaused || gameEnded) return;
    timer?.cancel();
    _musicPlayer.pause();
    _sfxPlayer.pause();
    setState(() {
      isPaused = true;
      showOptions = false;
    });
  }

  void resumeGame() {
    if (!isPaused || gameEnded) return;
    setState(() {
      isPaused = false;
      showOptions = false;
    });
    _startBackgroundMusic();
    _sfxPlayer.resume();
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
    _musicPlayer.stop();
    _musicStoppedForMute = true;
    if (passed) {
      confettiController.play();
      playCompleteSound();
    }
    saveScore();
  }

  Future<void> saveScore() async {
    try {
      await FirebaseFirestore.instance.collection('scores').add({
        'level': 'Pattern Logic',
        'patternCorrect': patternCorrect,
        'patternTotal': questions.length,
        'correct': patternCorrect,
        'wrong': patternWrong,
        'accuracy': accuracy,
        'xp': xp,
        'streak': bestStreak,
        'grade': getGrade(),
        'completed': passed,
        'timestamp': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error saving Pattern Logic score: $e');
    }
  }

  Widget _glassCard({required Widget child, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 20)}) {
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

  Widget _buildChunkyButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), offset: const Offset(0, 4), blurRadius: 8)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String title, String value) {
    return Column(children: [
      Text(title, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildHudCard({required IconData icon, required String title, required String value, required Color valueColor}) {
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
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
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const SizedBox(width: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
            child: const Text('Pattern Logic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (!gameEnded)
            IconButton(
              onPressed: pauseGame,
              icon: const Icon(Icons.pause_circle_filled, color: Colors.amber, size: 32),
            )
          else
            const SizedBox(width: 48),
        ]),
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
      child: Column(children: [
        Row(children: [
          Expanded(child: _buildHudCard(icon: Icons.timer_outlined, title: 'TIME', value: '${displayTime}s', valueColor: timeColor)),
          const SizedBox(width: 6),
          Expanded(child: _buildHudCard(icon: Icons.star_rounded, title: 'XP', value: '$xp', valueColor: Colors.amber)),
          const SizedBox(width: 6),
          Expanded(child: _buildHudCard(icon: Icons.local_fire_department, title: 'STREAK', value: '$streak', valueColor: Colors.orangeAccent)),
          const SizedBox(width: 6),
          Expanded(child: _buildHudCard(icon: Icons.emoji_events_rounded, title: 'BEST', value: '$bestStreak', valueColor: Colors.purpleAccent)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('QUESTION ${patternIndex + 1}/${questions.length}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: (displayTime / patternQuestionDuration).clamp(0.0, 1.0), minHeight: 8, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(timeColor)),
                  ),
                  const SizedBox(height: 14),
                  _glassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                    child: Text(pattern, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0),
                    itemCount: answers.length,
                    itemBuilder: (context, index) => _buildAnswerButton(answers[index].toString()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 28,
                    child: feedbackText.isEmpty ? null : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(feedbackText, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: lastAnswerCorrect ? Colors.greenAccent : Colors.redAccent)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(answered ? 'Get ready for the next question...' : 'Pick the answer that continues the pattern', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
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
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: answered && isCorrectAnswer ? Colors.greenAccent : Colors.white24, width: answered && isCorrectAnswer ? 3 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(answer, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsVolumeSlider({required String title, required IconData icon, required double value, required ValueChanged<double> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        ]),
        Slider(value: value, min: 0, max: 1, divisions: 20, activeColor: Colors.amber, inactiveColor: Colors.white24, onChanged: onChanged),
      ]),
    );
  }

  Widget _buildOptionsScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _glassCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.settings_rounded, color: Colors.amber, size: 44),
          const SizedBox(height: 8),
          const Text('GAME OPTIONS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 22),
          _buildOptionsVolumeSlider(title: 'Background Music', icon: Icons.music_note_rounded, value: musicVolume, onChanged: changeMusicVolume),
          const SizedBox(height: 12),
          _buildOptionsVolumeSlider(title: 'Sound Effects', icon: Icons.volume_up_rounded, value: soundVolume, onChanged: changeSoundVolume),
          const SizedBox(height: 20),
          _buildChunkyButton(label: 'Back to Pause Menu', icon: Icons.arrow_back_rounded, color: const Color(0xFF2EC4B6), onPressed: () => setState(() => showOptions = false)),
        ])),
      ),
    );
  }

  Widget _buildResultScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: _glassCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(passed ? '🎉 LEVEL COMPLETE!' : '😅 KEEP PRACTICING!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: passed ? Colors.amber : Colors.redAccent, letterSpacing: 1), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(passed ? 'Great job spotting the patterns!' : 'Try again to improve your pattern logic score.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)),
            child: Text('GRADE: ${getGrade()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.amber)),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildStatBadge('⭐ XP', '+$xp'),
            _buildStatBadge('🎯 Accuracy', '${accuracy.toStringAsFixed(0)}%'),
            _buildStatBadge('🔥 Best', '$bestStreak'),
          ]),
          const SizedBox(height: 14),
          _buildStatBadge('🧩 Correct Answers', '$patternCorrect/${questions.length}'),
          const SizedBox(height: 20),
          _buildChunkyButton(label: 'Try Again', icon: Icons.refresh_rounded, color: const Color(0xFF2EC4B6), onPressed: restartGame),
          const SizedBox(height: 10),
          _buildChunkyButton(label: 'Main Menu', icon: Icons.home_rounded, color: Colors.white24, onPressed: goToMainMenu),
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(children: [
          Column(children: [
            _buildCustomAppBar(),
            Expanded(
              child: AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(sin(_shakeController.value * pi * 6) * 8 * (1 - _shakeController.value), 0),
                  child: child,
                ),
                child: gameEnded ? _buildResultScreen() : _buildGameplay(),
              ),
            ),
          ]),
          if (isPaused && !showOptions)
            Positioned.fill(child: PauseMenu(onResume: resumeGame, onRestart: restartGame, onOptions: showGameOptions, onMainMenu: goToMainMenu)),
          if (isPaused && showOptions)
            Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.72), child: _buildOptionsScreen())),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(confettiController: confettiController, blastDirectionality: BlastDirectionality.explosive, shouldLoop: false, colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple, Colors.amber]),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _session++;
    timer?.cancel();
    confettiController.dispose();
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
    _shakeController.dispose();
    super.dispose();
  }
}
