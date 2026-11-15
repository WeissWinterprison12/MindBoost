import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_difficulty.dart';
import '../services/audio_settings.dart';
import '../services/score_identity.dart';
import '../widgets/options_menu.dart';
import '../widgets/pause_menu.dart';
import 'science_puzzle.dart';

class MathGame extends StatefulWidget {
  final GameDifficulty difficulty;

  const MathGame({super.key, this.difficulty = GameDifficulty.hard});

  @override
  State<MathGame> createState() => _MathGameState();
}

class _MathGameState extends State<MathGame> {
  final TextEditingController answerController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  late ConfettiController confettiController;
  Timer? questionTimer;

  final AudioPlayer _correctPlayer = AudioPlayer();
  final AudioPlayer _wrongPlayer = AudioPlayer();
  final AudioPlayer _completePlayer = AudioPlayer();
  late final List<AudioPlayer> _effectPlayers = [
    _correctPlayer,
    _wrongPlayer,
    _completePlayer,
  ];
  bool _effectsReady = false;
  final AudioPlayer _musicPlayer = AudioPlayer();

  int _answerNumerator = 0;
  int _answerDenominator = 1;
  String get correctAnswer => _answerDenominator == 1
      ? '$_answerNumerator'
      : '$_answerNumerator/$_answerDenominator';
  String question = '';
  int correctCount = 0;
  int wrongCount = 0;
  int questionCount = 0;
  static const int maxQuestions = 10;
  int questionTime = 10;

  int get timeLimit => switch (widget.difficulty) {
        GameDifficulty.easy => 0,
        GameDifficulty.medium => 30,
        GameDifficulty.hard => 45,
      };
  bool get hasTimer => widget.difficulty != GameDifficulty.easy;

  bool gameOver = false;
  bool isPaused = false;
  bool showOptions = false;
  double musicVolume = AudioSettings.defaultVolume;
  double soundVolume = AudioSettings.defaultVolume;
  double _lastMusicVolume = AudioSettings.defaultVolume;
  double _lastSoundVolume = AudioSettings.defaultVolume;
  bool _musicStoppedForMute = false;
  static const double _duckLevel = 0.3;
  int _duckToken = 0;

  int xp = 0;
  int streak = 0;
  int bestStreak = 0;
  bool showFeedback = false;
  String feedbackText = '';
  bool lastAnswerCorrect = false;
  bool showError = false;
  double shakeOffset = 0;
  double screenShake = 0;
  bool showXpPopup = false;
  int xpGained = 0;
  int _gameSession = 0;
  final List<String> _easyOperationDeck = [];
  final List<String> _mediumOperationDeck = [];
  final List<String> _hardQuestionDeck = [];

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    questionTime = timeLimit;
    _prepareQuestionDecks();
    _initAudio();
    generateQuestion();
  }

  // AUDIO
  Future<void> _initAudio() async {
    final settings = AudioSettings.instance;
    await settings.initialize();
    await settings.loadForCurrentUser();
    if (!mounted) return;
    setState(() {
      musicVolume = settings.musicVolume;
      soundVolume = settings.soundVolume;
      if (musicVolume > 0) _lastMusicVolume = musicVolume;
      if (soundVolume > 0) _lastSoundVolume = soundVolume;
    });
    await _configureAudio();
    await Future.wait([_loadSoundEffects(), _startBackgroundMusic()]);
  }

  Future<void> _loadSoundEffects() async {
    try {
      for (final player in _effectPlayers) {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(soundVolume);
      }
      await _correctPlayer.setSource(AssetSource('sounds/correct.mp3'));
      await _wrongPlayer.setSource(AssetSource('sounds/wrong.mp3'));
      await _completePlayer.setSource(AssetSource('sounds/level up.mp3'));
      _effectsReady = true;
    } catch (error) {
      debugPrint('Could not preload sound effects: $error');
    }
  }

  Future<void> _configureAudio() async {
    final audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    );
    try {
      await _musicPlayer.setAudioContext(audioContext);
      for (final player in _effectPlayers) {
        await player.setAudioContext(audioContext);
      }
    } catch (error) {
      debugPrint('Could not set audio mixing: $error');
    }
  }

  Future<void> _startBackgroundMusic() async {
    if (musicVolume <= 0) {
      _musicStoppedForMute = true;
      try {
        await _musicPlayer.stop();
      } catch (error) {
        debugPrint('Could not stop muted music: $error');
      }
      return;
    }
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(musicVolume);
      await _musicPlayer.play(
        AssetSource('sounds/Bouncing_Thoughts.mp3'),
        volume: musicVolume,
      );
      _musicStoppedForMute = false;
      debugPrint('Background music started at ${(musicVolume * 100).round()}%');
    } catch (error) {
      debugPrint('Could not play background music: $error');
    }
  }

  Future<void> _duckMusic(AudioPlayer effectPlayer) async {
    if (musicVolume <= 0 || _musicStoppedForMute || isPaused || gameOver) return;
    final token = ++_duckToken;
    final effectFinished = effectPlayer.onPlayerComplete.first;
    try {
      await _musicPlayer.setVolume(musicVolume * _duckLevel);
    } catch (error) {
      debugPrint('Could not lower music volume: $error');
    }
    try {
      await Future.any<void>([
        effectFinished,
        Future<void>.delayed(const Duration(seconds: 3)),
      ]);
    } catch (error) {
      debugPrint('Sound effect wait failed: $error');
    }
    if (!mounted || token != _duckToken) return;
    try {
      await _musicPlayer.setVolume(musicVolume);
    } catch (error) {
      debugPrint('Could not restore music volume: $error');
    }
  }

  Future<void> _playEffect(AudioPlayer player, String fileName) async {
    if (soundVolume <= 0) return;
    _duckMusic(player);
    try {
      if (_effectsReady) {
        await player.stop();
        await player.resume();
      } else {
        await player.play(AssetSource('sounds/$fileName'), volume: soundVolume);
      }
    } catch (error) {
      debugPrint('Could not play sound $fileName: $error');
      try {
        await player.play(AssetSource('sounds/$fileName'), volume: soundVolume);
      } catch (retryError) {
        debugPrint('Retry failed for $fileName: $retryError');
      }
    }
  }

  void playCorrectSound() => _playEffect(_correctPlayer, 'correct.mp3');
  void playWrongSound() => _playEffect(_wrongPlayer, 'wrong.mp3');
  void playCompleteSound() => _playEffect(_completePlayer, 'level up.mp3');

  Future<void> changeMusicVolume(double value) async {
    final volume = value.clamp(0.0, 1.0).toDouble();
    if (!mounted) return;
    setState(() {
      musicVolume = volume;
      if (volume > 0) _lastMusicVolume = volume;
    });
    await AudioSettings.instance.setMusicVolume(volume);
    try {
      if (volume <= 0) {
        _musicStoppedForMute = true;
        await _musicPlayer.stop();
        debugPrint('Background music muted: 0%');
        return;
      }
      if (_musicStoppedForMute) {
        if (isPaused || gameOver) {
          debugPrint('Music set to ${(volume * 100).round()}%; it will start when gameplay resumes.');
          return;
        }
        await _startBackgroundMusic();
        return;
      }
      await _musicPlayer.setVolume(volume);
      debugPrint('Background music volume set to ${(volume * 100).round()}%');
    } catch (error) {
      debugPrint('Could not change music volume: $error');
    }
  }

  Future<void> changeSoundVolume(double value) async {
    final volume = value.clamp(0.0, 1.0).toDouble();
    if (!mounted) return;
    setState(() {
      soundVolume = volume;
      if (volume > 0) _lastSoundVolume = volume;
    });
    await AudioSettings.instance.setSoundVolume(volume);
    try {
      for (final player in _effectPlayers) {
        await player.setVolume(volume);
      }
      debugPrint('Sound effects volume set to ${(volume * 100).round()}%');
    } catch (error) {
      debugPrint('Could not change sound volume: $error');
    }
  }

  void showGameOptions() {
    if (!mounted) return;
    setState(() => showOptions = true);
  }

  // PAUSE SYSTEM
  void pauseGame() {
    if (gameOver || isPaused) return;
    questionTimer?.cancel();
    _duckToken++;
    setState(() {
      isPaused = true;
      showOptions = false;
    });
    FocusScope.of(context).unfocus();
    for (final player in _effectPlayers) {
      player.pause();
    }
    _musicPlayer.pause();
  }

  Future<void> resumeGame() async {
    if (!isPaused || gameOver) return;
    setState(() {
      isPaused = false;
      showOptions = false;
    });
    try {
      if (musicVolume <= 0) {
        await _musicPlayer.stop();
        _musicStoppedForMute = true;
      } else if (_musicStoppedForMute) {
        await _startBackgroundMusic();
      } else {
        await _musicPlayer.setVolume(musicVolume);
        await _musicPlayer.resume();
      }
    } catch (error) {
      debugPrint('Could not resume background music: $error');
    }
    if (!mounted) return;
    try {
      for (final player in _effectPlayers) {
        await player.setVolume(soundVolume);
      }
    } catch (error) {
      debugPrint('Could not restore sound volume: $error');
    }
    if (!mounted) return;
    startQuestionTimer(resetTime: false);
  }

  // QUESTION TIMER
  void startQuestionTimer({bool resetTime = true}) {
    questionTimer?.cancel();
    if (!hasTimer) {
      if (mounted) {
        setState(() => questionTime = 0);
      } else {
        questionTime = 0;
      }
      return;
    }
    if (resetTime) questionTime = timeLimit;
    questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (isPaused || gameOver) return;
      if (questionTime <= 1) {
        timer.cancel();
        setState(() => questionTime = 0);
        handleTimeout();
      } else {
        setState(() => questionTime--);
      }
    });
  }

  // TIMEOUT
  void handleTimeout() {
    questionTimer?.cancel();
    final currentSession = _gameSession;
    feedbackText = "Time's up! ❌ Correct: $correctAnswer";
    wrongCount++;
    streak = 0;
    setState(() {
      showFeedback = true;
      lastAnswerCorrect = false;
    });
    answerController.clear();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || isPaused || currentSession != _gameSession) return;
      setState(() {
        showFeedback = false;
        questionCount++;
      });
      if (questionCount >= maxQuestions) {
        setState(() => gameOver = true);
        _musicPlayer.stop();
        playCompleteSound();
        confettiController.play();
        saveScore();
        return;
      }
      generateQuestion();
    });
  }

  // ERROR ANIMATION
  void triggerError() {
    if (isPaused) return;
    setState(() {
      showError = true;
      shakeOffset = 10;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || isPaused) return;
      setState(() => shakeOffset = -10);
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || isPaused) return;
      setState(() => shakeOffset = 10);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || isPaused) return;
      setState(() => shakeOffset = 0);
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || isPaused) return;
      setState(() => showError = false);
    });
  }

  // SCREEN SHAKE
  void triggerScreenShake() {
    if (isPaused) return;
    setState(() => screenShake = 10);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || isPaused) return;
      setState(() => screenShake = -10);
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || isPaused) return;
      setState(() => screenShake = 10);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || isPaused) return;
      setState(() => screenShake = 0);
    });
  }

  // XP POPUP
  void showXpGain(int amount) {
    if (isPaused) return;
    setState(() {
      showXpPopup = true;
      xpGained = amount;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || isPaused) return;
      setState(() => showXpPopup = false);
    });
  }

  // GENERATE QUESTION
  void _prepareQuestionDecks() {
    _easyOperationDeck
      ..clear()
      ..addAll(['+', '−', '×', '÷', '+', '−', '×', '÷', '+', '−'])
      ..shuffle(Random());
    _mediumOperationDeck
      ..clear()
      ..addAll(['+', '−', '×', '÷', '+', '−', '×'])
      ..shuffle(Random());
    _hardQuestionDeck
      ..clear()
      ..addAll([
        'fraction:+', 'fraction:−', 'fraction:×', 'fraction:÷',
        'gcf', 'gcf', 'lcd', 'lcd', 'geometry', 'geometry',
      ])
      ..shuffle(Random());
  }

  int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    return a == 0 ? 1 : a;
  }

  int _lcm(int a, int b) => (a ~/ _gcd(a, b)) * b;

  void _setQuestion(String prompt, int numerator, [int denominator = 1]) {
    if (denominator < 0) {
      numerator = -numerator;
      denominator = -denominator;
    }
    final divisor = _gcd(numerator, denominator);
    _answerNumerator = numerator ~/ divisor;
    _answerDenominator = denominator ~/ divisor;
    question = prompt;
  }

  (int, int) _randomFraction(Random random, {required bool hard}) {
    final denominators = hard
        ? const [3, 4, 5, 6, 8, 10, 12]
        : const [2, 3, 4, 5, 6];
    final denominator = denominators[random.nextInt(denominators.length)];
    final numerator = random.nextInt(denominator - 1) + 1;
    return (numerator, denominator);
  }

  void _generateIntegerMdas(Random random, {required String symbol}) {
    late int a;
    late int b;
    late int answer;

    switch (symbol) {
      case '+':
        a = random.nextInt(40) + 10;
        b = random.nextInt(40) + 10;
        answer = a + b;
        break;
      case '−':
        a = random.nextInt(41) + 10;
        b = random.nextInt(a - 9) + 1;
        answer = a - b;
        break;
      case '×':
        a = random.nextInt(11) + 2;
        b = random.nextInt(9) + 2;
        answer = a * b;
        break;
      default:
        b = random.nextInt(10) + 2;
        answer = random.nextInt(10) + 2;
        a = b * answer;
    }
    _setQuestion('$a $symbol $b = ?', answer);
  }

  void _generateFractionMdas(
    Random random, {
    required bool hard,
    required String symbol,
  }) {
    final first = _randomFraction(random, hard: hard);
    final second = _randomFraction(random, hard: hard);
    var a = first.$1;
    var b = first.$2;
    var c = second.$1;
    var d = second.$2;
    late int numerator;
    late int denominator;

    switch (symbol) {
      case '+':
        numerator = a * d + c * b;
        denominator = b * d;
        break;
      case '−':
        if (a * d < c * b) {
          final oldA = a;
          final oldB = b;
          a = c;
          b = d;
          c = oldA;
          d = oldB;
        }
        numerator = a * d - c * b;
        denominator = b * d;
        break;
      case '×':
        numerator = a * c;
        denominator = b * d;
        break;
      default:
        numerator = a * d;
        denominator = b * c;
    }

    _setQuestion(
      '($a/$b) $symbol ($c/$d) = ?',
      numerator,
      denominator,
    );
  }

  void _generateGcfQuestion(Random random) {
    final shared = random.nextInt(10) + 2;
    final a = shared * (random.nextInt(7) + 2);
    final b = shared * (random.nextInt(7) + 2);
    _setQuestion('GCF of $a and $b = ?', _gcd(a, b));
  }

  void _generateLcdQuestion(Random random) {
    const denominators = [3, 4, 5, 6, 8, 10, 12];
    final first = denominators[random.nextInt(denominators.length)];
    var second = denominators[random.nextInt(denominators.length)];
    while (second == first) {
      second = denominators[random.nextInt(denominators.length)];
    }
    final numeratorA = random.nextInt(first - 1) + 1;
    final numeratorB = random.nextInt(second - 1) + 1;
    _setQuestion(
      'LCD of $numeratorA/$first and $numeratorB/$second = ?',
      _lcm(first, second),
    );
  }

  void _generateGeometryQuestion(Random random) {
    switch (random.nextInt(4)) {
      case 0:
        final length = random.nextInt(8) + 5;
        final width = random.nextInt(7) + 4;
        _setQuestion(
          'Area of a $length cm × $width cm rectangle = ? cm²',
          length * width,
        );
        break;
      case 1:
        final length = random.nextInt(9) + 6;
        final width = random.nextInt(7) + 4;
        _setQuestion(
          'Perimeter of a $length cm × $width cm rectangle = ? cm',
          2 * (length + width),
        );
        break;
      case 2:
        final base = (random.nextInt(6) + 4) * 2;
        final height = random.nextInt(8) + 3;
        _setQuestion(
          'Area of a triangle: base $base cm, height $height cm = ? cm²',
          base * height ~/ 2,
        );
        break;
      default:
        final side = random.nextInt(9) + 4;
        _setQuestion(
          'Perimeter of a square with side $side cm = ? cm',
          side * 4,
        );
    }
  }

  void generateQuestion() {
    if (gameOver || isPaused) return;
    final random = Random();

    switch (widget.difficulty) {
      case GameDifficulty.easy:
        _generateIntegerMdas(
          random,
          symbol: _easyOperationDeck[questionCount % _easyOperationDeck.length],
        );
        break;
      case GameDifficulty.medium:
        _generateFractionMdas(
          random,
          hard: false,
          symbol:
              _mediumOperationDeck[questionCount % _mediumOperationDeck.length],
        );
        break;
      case GameDifficulty.hard:
        if (_hardQuestionDeck.isEmpty) _prepareQuestionDecks();
        final questionType =
            _hardQuestionDeck[questionCount % _hardQuestionDeck.length];
        if (questionType.startsWith('fraction:')) {
          _generateFractionMdas(
            random,
            hard: true,
            symbol: questionType.split(':').last,
          );
          break;
        }
        switch (questionType) {
          case 'gcf':
            _generateGcfQuestion(random);
            break;
          case 'lcd':
            _generateLcdQuestion(random);
            break;
          case 'geometry':
            _generateGeometryQuestion(random);
            break;
          default:
            _generateFractionMdas(random, hard: true, symbol: '+');
        }
        break;
    }

    setState(() {});
    startQuestionTimer();
  }

  bool _matchesAnswer(String input) {
    final answer = input.trim().replaceAll(' ', '');
    if (answer.isEmpty) return false;

    final parts = answer.split('/');
    if (parts.length == 2) {
      final numerator = int.tryParse(parts[0]);
      final denominator = int.tryParse(parts[1]);
      if (numerator == null || denominator == null || denominator == 0) {
        return false;
      }
      return numerator * _answerDenominator ==
          _answerNumerator * denominator;
    }

    final decimal = double.tryParse(answer);
    if (decimal == null) return false;
    return (decimal - _answerNumerator / _answerDenominator).abs() < 0.0001;
  }

  // CHECK ANSWER
  void checkAnswer({bool isTimeout = false}) {
    if (isPaused || gameOver) return;
    if (answerController.text.trim().isEmpty) {
      triggerError();
      return;
    }
    questionTimer?.cancel();
    bool isCorrect = _matchesAnswer(answerController.text);
    if (isTimeout) {
      isCorrect = false;
      feedbackText = "Time's up! ❌ Correct: $correctAnswer";
    } else if (isCorrect) {
      feedbackText = 'CORRECT! 🎉';
    } else {
      feedbackText = 'WRONG! ❌ Correct: $correctAnswer';
    }
    if (isCorrect) {
      correctCount++;
      streak++;
      var xpEarned = 10;
      if (streak % 3 == 0) xpEarned += 5;
      xp += xpEarned;
      if (streak > bestStreak) bestStreak = streak;
      playCorrectSound();
      showXpGain(xpEarned);
    } else {
      wrongCount++;
      streak = 0;
      playWrongSound();
      triggerScreenShake();
    }
    setState(() {
      showFeedback = true;
      lastAnswerCorrect = isCorrect;
    });
    answerController.clear();
    final currentSession = _gameSession;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || isPaused || currentSession != _gameSession) return;
      setState(() {
        showFeedback = false;
        questionCount++;
      });
      if (questionCount >= maxQuestions) {
        setState(() => gameOver = true);
        _musicPlayer.stop();
        playCompleteSound();
        confettiController.play();
        saveScore();
        return;
      }
      generateQuestion();
    });
  }

  // SCORE / GRADE
  double get accuracy => questionCount == 0 ? 0 : (correctCount / questionCount) * 100;

  String getGrade() {
    final percent = accuracy;
    if (percent >= 90) return 'S';
    if (percent >= 80) return 'A';
    if (percent >= 70) return 'B';
    if (percent >= 60) return 'C';
    return 'D';
  }

  // FIRESTORE
  Future<void> saveScore() async {
    try {
      final identityFields = await ScoreIdentity.fields();
      await FirebaseFirestore.instance.collection('scores').add({
        ...identityFields,
        'level': 1,
        'levelName': 'Math',
        'difficulty': widget.difficulty.label,
        'correct': correctCount,
        'wrong': wrongCount,
        'accuracy': accuracy,
        'xp': xp,
        'streak': bestStreak,
        'grade': getGrade(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('Math Game score saved successfully.');
    } catch (error) {
      debugPrint('Could not save Math Game score: $error');
    }
  }

  // RESTART GAME
  void restartGame() {
    questionTimer?.cancel();
    _gameSession++;
    _duckToken++;
    setState(() {
      _answerNumerator = 0;
      _answerDenominator = 1;
      question = '';
      correctCount = 0;
      wrongCount = 0;
      questionCount = 0;
      questionTime = timeLimit;
      gameOver = false;
      isPaused = false;
      showOptions = false;
      xp = 0;
      streak = 0;
      bestStreak = 0;
      showFeedback = false;
      feedbackText = '';
      lastAnswerCorrect = false;
      showError = false;
      shakeOffset = 0;
      screenShake = 0;
      showXpPopup = false;
      xpGained = 0;
      answerController.clear();
    });
    _prepareQuestionDecks();
    _startBackgroundMusic();
    generateQuestion();
  }

  void goToMainMenu() => Navigator.pop(context);

  // NEXT LEVEL → Science Puzzle (same difficulty)
  void goToNextLevel() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SciencePuzzle(
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameSession++;
    _duckToken++;
    confettiController.dispose();
    questionTimer?.cancel();
    for (final player in _effectPlayers) {
      player.dispose();
    }
    _musicPlayer.dispose();
    focusNode.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Transform.translate(
                offset: Offset(screenShake, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildTopHeader(context),
                      Expanded(child: gameOver ? _buildLevelCompleteScreen() : _buildGameplayScreen()),
                    ],
                  ),
                ),
              ),
              if (showXpPopup)
                Positioned(
                  top: 180,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: showXpPopup ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Text('+$xpGained XP', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF4A0E4E))),
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [Color(0xFFFFD700), Color(0xFF38EF7D), Color(0xFFFF8008), Colors.pink, Colors.purple],
                ),
              ),
              if (isPaused)
                Positioned.fill(
                  child: showOptions
                      ? _buildOptionsScreen()
                      : PauseMenu(onResume: resumeGame, onRestart: restartGame, onOptions: showGameOptions, onMainMenu: goToMainMenu),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMusicMute() =>
      changeMusicVolume(musicVolume <= 0 ? _lastMusicVolume : 0.0);

  Future<void> _toggleSoundMute() =>
      changeSoundVolume(soundVolume <= 0 ? _lastSoundVolume : 0.0);

  Future<void> _toggleMuteAll() async {
    if (musicVolume <= 0 && soundVolume <= 0) {
      await Future.wait([
        changeMusicVolume(_lastMusicVolume),
        changeSoundVolume(_lastSoundVolume),
      ]);
    } else {
      if (musicVolume > 0) _lastMusicVolume = musicVolume;
      if (soundVolume > 0) _lastSoundVolume = soundVolume;
      await Future.wait([
        changeMusicVolume(0.0),
        changeSoundVolume(0.0),
      ]);
    }
  }

  Widget _buildOptionsScreen() {
    return OptionsMenu(
      musicVolume: musicVolume,
      onMusicVolumeChanged: changeMusicVolume,
      onMusicMuteToggle: _toggleMusicMute,
      soundVolume: soundVolume,
      onSoundVolumeChanged: changeSoundVolume,
      onSoundMuteToggle: _toggleSoundMute,
      onMuteAll: _toggleMuteAll,
      allMuted: musicVolume <= 0 && soundVolume <= 0,
      onBack: () => setState(() => showOptions = false),
    );
  }

  // HEADER
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFD700), width: 1.5)),
            child: Column(
              children: [
                const Text('LEVEL 1: MATH', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                Text('${widget.difficulty.label} MODE', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1)),
              ],
            ),
          ),
          if (!gameOver && !isPaused)
            IconButton(onPressed: pauseGame, icon: const Icon(Icons.pause_circle_filled, color: Colors.amber, size: 32))
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // GAMEPLAY SCREEN
  Widget _buildGameplayScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHudItem('⭐ XP', '$xp', Colors.amber),
              _buildHudItem('🔥 Streak', '$streak', Colors.orangeAccent),
              _buildHudItem('🏆 Best', '$bestStreak', Colors.cyanAccent),
            ],
          ),
        ),
        Column(
          children: [
            Text('QUESTION ${questionCount + 1} OF $maxQuestions', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            if (hasTimer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: questionTime <= 3 ? Colors.redAccent.withOpacity(0.3) : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: questionTime <= 3 ? Colors.redAccent : Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, color: questionTime <= 3 ? Colors.redAccent : const Color(0xFFFFD700), size: 20),
                    const SizedBox(width: 6),
                    Text('$questionTime SEC', style: TextStyle(color: questionTime <= 3 ? Colors.redAccent : const Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
              )
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 8))],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                question,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(2, 3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            Transform.translate(
              offset: Offset(shakeOffset, 0),
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: showError ? Colors.redAccent : const Color(0xFFFFD700), width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: TextField(
                  controller: answerController,
                  focusNode: focusNode,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9./-]')),
                  ],
                  enabled: !isPaused && !gameOver,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2E0854)),
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10), hintText: '?', hintStyle: TextStyle(color: Colors.black26, fontSize: 32, fontWeight: FontWeight.w900)),
                  onSubmitted: (_) => checkAnswer(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _3DButton(text: 'SUBMIT', color: const Color(0xFF38EF7D), shadowColor: const Color(0xFF0C6B63), textColor: const Color(0xFF003816), onPressed: isPaused ? () {} : checkAnswer),
          ],
        ),
        AnimatedOpacity(
          opacity: showFeedback ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: lastAnswerCorrect ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: lastAnswerCorrect ? Colors.green : Colors.redAccent),
            ),
            child: Text(feedbackText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: lastAnswerCorrect ? Colors.greenAccent : Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  // LEVEL COMPLETE SCREEN
  Widget _buildLevelCompleteScreen() {
    final passed = accuracy >= 60;
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
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(passed ? '🎉 LEVEL COMPLETE!' : '😅 KEEP PRACTICING!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: passed ? Colors.amber : Colors.redAccent, letterSpacing: 1), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(passed ? 'Great job! You solved the math questions.' : 'Not quite enough correct answers. Try again!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber)),
                    child: Text('GRADE: ${getGrade()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.amber)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBadge('⭐ XP', '+$xp'),
                      _buildStatBadge('🔥 Streak', '$bestStreak'),
                      _buildStatBadge('✅ Correct', '$correctCount/$maxQuestions'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('🎯 Accuracy: ${accuracy.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  _buildChunkyButton(label: 'Try Again', icon: Icons.refresh_rounded, color: const Color(0xFF2EC4B6), onPressed: restartGame),
                  // Next Level is always shown (Level 1 has no Previous button).
                  // It opens the next level with the SAME difficulty.
                  const SizedBox(height: 10),
                  _buildChunkyButton(
                    label: 'Next Level',
                    icon: Icons.arrow_forward_rounded,
                    color: const Color(0xFFFFD700),
                    onPressed: goToNextLevel,
                  ),
                  const SizedBox(height: 10),
                  _buildChunkyButton(label: 'Main Menu', icon: Icons.home_rounded, color: Colors.white24, onPressed: goToMainMenu),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildChunkyButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: _3DButton(text: label, icon: icon, color: color, shadowColor: Colors.black38, textColor: Colors.white, onPressed: onPressed),
    );
  }

  Widget _buildHudItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

// 3D BUTTON WIDGET
class _3DButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final Color shadowColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _3DButton({required this.text, this.icon, required this.color, required this.shadowColor, required this.textColor, required this.onPressed});

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
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: widget.shadowColor, offset: Offset(0, _isPressed ? 0 : 5), blurRadius: 0)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: widget.textColor, size: 22),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(widget.text, textAlign: TextAlign.center, style: TextStyle(color: widget.textColor, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
