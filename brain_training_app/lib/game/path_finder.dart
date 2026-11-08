import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/game_difficulty.dart';
import '../services/audio_settings.dart';
import '../services/score_identity.dart';
import '../widgets/pause_menu.dart';
import '../widgets/player_avatar.dart';

class PathFinder extends StatefulWidget {
  final GameDifficulty difficulty;

  const PathFinder({super.key, this.difficulty = GameDifficulty.medium});

  @override
  State<PathFinder> createState() => _PathFinderState();
}

class _PathFinderState extends State<PathFinder> {
  int get maxRounds => switch (widget.difficulty) {
        GameDifficulty.easy => 3,
        GameDifficulty.medium => 3,
        GameDifficulty.hard => 5,
      };
  static const int startingLives = 3;

  static const Color wallColor = Color(0xFF3A0F52);
  static const Color corridorColor = Color(0xFFEDE3FF);
  static const Color startColor = Color(0xFF38EF7D);
  static const Color finishColor = Color(0xFFFFD700);

  final Random random = Random();
  final AudioPlayer audioPlayer = AudioPlayer(); // Sound effects
  final AudioPlayer musicPlayer = AudioPlayer(); // Background music
  final ConfettiController confettiController =
      ConfettiController(duration: const Duration(seconds: 3));
  final Set<String> usedMazeSignatures = {};

  Timer? gameTimer;

  int currentRound = 1;
  int lives = startingLives;
  int secondsRemaining = 8;
  int roundsCompleted = 0;
  int totalMoves = 0;
  int mistakes = 0;
  int xp = 0;

  int mazeSize = 7;
  int solveTimeLimit = 45;
  int previewTimeLimit = 8;

  double musicVolume = AudioSettings.defaultVolume;
  double soundVolume = AudioSettings.defaultVolume;

  List<List<bool>> maze = [];
  List<Point<int>> tracedPath = [];

  // Start and finish are picked at random for every maze.
  Point<int> start = const Point<int>(1, 1);
  Point<int> goal = const Point<int>(5, 5);

  // The player's avatar, shown on the start cell.
  int playerAvatar = 0;

  bool isPreview = true;
  bool isMistakeReveal = false;
  bool showTryAgain = false;
  bool isPaused = false;
  bool isGameOver = false;
  bool isDragging = false;
  bool hasStarted = false;
  bool isRoundComplete = false;
  bool showOptions = false;
  bool musicStoppedForMute = false;

  @override
  void initState() {
    super.initState();
    _prepareRound();
    _initAudio();
    _loadPlayerAvatar();
  }

  /// Uses the same avatar the player picked in their profile
  /// (the one shown on the level select screen).
  Future<void> _loadPlayerAvatar() async {
    try {
      final me = await ScoreIdentity.load();
      if (!mounted) return;
      setState(() => playerAvatar = me.avatar);
    } catch (error) {
      debugPrint('Could not load player avatar: $error');
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    audioPlayer.dispose();
    musicPlayer.dispose();
    confettiController.dispose();
    super.dispose();
  }

  // ============================================================
  // AUDIO AND OPTIONS
  // ============================================================

  Future<void> _initAudio() async {
    try {
      await AudioSettings.instance.initialize();
      await AudioSettings.instance.loadForCurrentUser();
      if (!mounted) return;

      setState(() {
        musicVolume = AudioSettings.instance.musicVolume;
        soundVolume = AudioSettings.instance.soundVolume;
      });

      // Must run before any sound plays, so effects never take the
      // audio focus away from the background music.
      await _configureAudio();

      await musicPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.setVolume(soundVolume);
      await _startBackgroundMusic();
    } catch (error) {
      debugPrint('Could not initialize Path Finder audio: $error');
    }
  }

  /// Lets the music and the sound effects play at the same time.
  /// Without this, playing an effect (like the "correct" sound) makes
  /// the system take the audio focus and the music stops.
  Future<void> _configureAudio() async {
    final audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    );
    try {
      await musicPlayer.setAudioContext(audioContext);
      await audioPlayer.setAudioContext(audioContext);
    } catch (error) {
      debugPrint('Could not set audio mixing: $error');
    }
  }

  Future<void> _startBackgroundMusic() async {
    try {
      await musicPlayer.stop();
      if (musicVolume <= 0 || isGameOver || isPaused || showOptions) return;
      await musicPlayer.setReleaseMode(ReleaseMode.loop);
      await musicPlayer.setVolume(musicVolume);
      await musicPlayer.play(
        AssetSource('sounds/The_Pattern_Unfolds.mp3'),
      );
    } catch (error) {
      debugPrint('Could not play Path Finder background music: $error');
    }
  }

  Future<void> _resumeBackgroundMusic() async {
    if (musicVolume <= 0 || isGameOver || isPaused || showOptions) return;
    try {
      await musicPlayer.setVolume(musicVolume);
      await musicPlayer.resume();
    } catch (_) {
      await _startBackgroundMusic();
    }
  }

  /// Safety net: if anything made the music stop while it should be
  /// playing, start it again.
  Future<void> _keepMusicPlaying() async {
    if (!mounted ||
        musicVolume <= 0 ||
        isGameOver ||
        isPaused ||
        showOptions) {
      return;
    }
    try {
      if (musicPlayer.state != PlayerState.playing) {
        await musicPlayer.resume();
      }
    } catch (_) {
      // The music is not essential; the game keeps going.
    }
  }

  Future<void> changeMusicVolume(double value) async {
    final wasMuted = musicVolume <= 0;
    setState(() {
      musicVolume = value;
      musicStoppedForMute = value <= 0;
    });

    try {
      await AudioSettings.instance.setMusicVolume(value);
      if (value <= 0) {
        await musicPlayer.pause();
        return;
      }
      await musicPlayer.setVolume(value);
      if (isPaused || showOptions || isGameOver) return;
      if (wasMuted) {
        await _startBackgroundMusic();
      } else {
        await _resumeBackgroundMusic();
      }
    } catch (error) {
      debugPrint('Could not change music volume: $error');
    }
  }

  Future<void> changeSoundVolume(double value) async {
    setState(() => soundVolume = value);
    try {
      await AudioSettings.instance.setSoundVolume(value);
      await audioPlayer.setVolume(value);
    } catch (error) {
      debugPrint('Could not change sound volume: $error');
    }
  }

  void _showGameOptions() {
    if (!mounted) return;
    setState(() => showOptions = true);
  }

  void _hideGameOptions() {
    if (!mounted) return;
    setState(() => showOptions = false);
  }

  // OPTIONS SCREEN (same design as the Math game)
  Widget _buildOptionsScreen() {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)],
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
                    color: const Color(0xFF3B0B46).withValues(alpha: 0.96),
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
                          color: Colors.white.withValues(alpha: 0.85),
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
                      _buildOptionsButton(
                        text: '← Back',
                        color: const Color(0xFFFFD700),
                        shadowColor: const Color(0xFFB8860B),
                        textColor: const Color(0xFF3B0B46),
                        onPressed: _hideGameOptions,
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
    final percentage = (value * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.65),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFFD700),
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFFFFD700).withValues(alpha: 0.18),
              trackHeight: 6,
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              min: 0,
              max: 1,
              divisions: 100,
              label: '$percentage%',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsButton({
    required String text,
    required Color color,
    required Color shadowColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return _3DButton(
      text: text,
      color: color,
      shadowColor: shadowColor,
      textColor: textColor,
      onPressed: onPressed,
    );
  }

  // ============================================================
  // ROUND SETTINGS
  // ============================================================

  int _settingsRoundForCurrentRound() {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return currentRound <= 2 ? 1 : 2;
      case GameDifficulty.medium:
        return currentRound; // Existing rounds 1, 2, and 3.
      case GameDifficulty.hard:
        if (currentRound == 1) return 1;
        if (currentRound <= 3) return 2;
        return currentRound - 1; // Rounds 4 and 5 use settings 3 and 4.
    }
  }

  int _sizeForRound(int round) {
    switch (round) {
      case 1:
        return 7;
      case 2:
        return 9;
      case 3:
        return 11;
      case 4:
        return 13;
      default:
        return 15;
    }
  }

  int _previewSecondsForRound(int round) => max(4, 9 - round);
  int _solveSecondsForRound(int round) => 50 - (round * 5);

  void _prepareRound() {
    if (isGameOver || lives <= 0) return;
    gameTimer?.cancel();

    final settingsRound = _settingsRoundForCurrentRound();
    mazeSize = _sizeForRound(settingsRound);
    previewTimeLimit = _previewSecondsForRound(settingsRound);
    solveTimeLimit = _solveSecondsForRound(settingsRound);

    // Random start anywhere on the map, then a maze grown from it,
    // then a random finish that is a good distance away.
    start = _randomCell(mazeSize);
    maze = _generateFreshMaze(mazeSize, start);
    goal = _pickGoal(maze, start);
    tracedPath = [start];
    isPreview = true;
    isMistakeReveal = false;
    isRoundComplete = false;
    showTryAgain = false;
    isDragging = false;
    secondsRemaining = previewTimeLimit;
    hasStarted = true;

    if (mounted) setState(() {});
    _startTimer();
  }

  // ============================================================
  // MAZE GENERATION
  // ============================================================

  /// A random cell centre. Cells sit on odd coordinates (1, 3, 5 ...),
  /// so every corridor junction on the map can be picked.
  Point<int> _randomCell(int size) {
    final int cellsPerSide = (size - 1) ~/ 2;
    return Point<int>(
      1 + 2 * random.nextInt(cellsPerSide),
      1 + 2 * random.nextInt(cellsPerSide),
    );
  }

  /// Picks the finish at random among the cells that are far from the
  /// start (at least 60% of the longest possible route), so the finish
  /// can be anywhere on the map but is never right next to the start.
  Point<int> _pickGoal(List<List<bool>> grid, Point<int> origin) {
    final int size = grid.length;
    final dist = List.generate(size, (_) => List<int>.filled(size, -1));
    final queue = <Point<int>>[origin];
    dist[origin.y][origin.x] = 0;

    const steps = <Point<int>>[
      Point<int>(0, -1),
      Point<int>(0, 1),
      Point<int>(-1, 0),
      Point<int>(1, 0),
    ];

    int head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      for (final step in steps) {
        final int nx = current.x + step.x;
        final int ny = current.y + step.y;
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
        if (!grid[ny][nx] || dist[ny][nx] != -1) continue;
        dist[ny][nx] = dist[current.y][current.x] + 1;
        queue.add(Point<int>(nx, ny));
      }
    }

    int maxDistance = 0;
    for (int y = 1; y < size - 1; y += 2) {
      for (int x = 1; x < size - 1; x += 2) {
        if (dist[y][x] > maxDistance) maxDistance = dist[y][x];
      }
    }

    final int minDistance = max(1, (maxDistance * 0.6).ceil());
    final candidates = <Point<int>>[];
    for (int y = 1; y < size - 1; y += 2) {
      for (int x = 1; x < size - 1; x += 2) {
        if (dist[y][x] >= minDistance) candidates.add(Point<int>(x, y));
      }
    }

    if (candidates.isEmpty) {
      // Cannot happen in a normal maze; keeps the game safe anyway.
      return Point<int>(size - 2, size - 2);
    }
    return candidates[random.nextInt(candidates.length)];
  }

  List<List<bool>> _generateMaze(int size, Point<int> origin) {
    final grid = List.generate(size, (_) => List<bool>.filled(size, false));
    final visited = <Point<int>>{};
    final stack = <Point<int>>[origin];
    grid[origin.y][origin.x] = true;
    visited.add(origin);

    const directions = <Point<int>>[
      Point<int>(0, -2),
      Point<int>(0, 2),
      Point<int>(-2, 0),
      Point<int>(2, 0),
    ];

    while (stack.isNotEmpty) {
      final current = stack.last;
      final neighbors = <Point<int>>[];
      for (final direction in directions) {
        final next = Point<int>(
          current.x + direction.x,
          current.y + direction.y,
        );
        if (next.x > 0 &&
            next.y > 0 &&
            next.x < size - 1 &&
            next.y < size - 1 &&
            !visited.contains(next)) {
          neighbors.add(next);
        }
      }
      if (neighbors.isEmpty) {
        stack.removeLast();
        continue;
      }
      final next = neighbors[random.nextInt(neighbors.length)];
      final middle = Point<int>(
        (current.x + next.x) ~/ 2,
        (current.y + next.y) ~/ 2,
      );
      grid[middle.y][middle.x] = true;
      grid[next.y][next.x] = true;
      visited.add(next);
      stack.add(next);
    }

    return grid;
  }

  List<List<bool>> _generateFreshMaze(int size, Point<int> origin) {
    for (int attempt = 0; attempt < 100; attempt++) {
      final candidate = _generateMaze(size, origin);
      final signature = candidate
          .map((row) => row.map((cell) => cell ? '1' : '0').join())
          .join();
      if (usedMazeSignatures.add(signature)) return candidate;
    }
    return _generateMaze(size, origin);
  }

  // ============================================================
  // TIMER AND SOUND EFFECTS
  // ============================================================

  void _startTimer() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || isPaused || showOptions || isGameOver) return;
      if (isMistakeReveal) {
        if (secondsRemaining > 1) {
          setState(() => secondsRemaining--);
        } else {
          _resolveFailedAttempt();
        }
        return;
      }
      if (secondsRemaining > 1) {
        setState(() => secondsRemaining--);
        return;
      }
      if (isPreview) {
        setState(() {
          isPreview = false;
          secondsRemaining = solveTimeLimit;
        });
        return;
      }
      _loseLifeForTimeout();
    });
  }

  Future<void> _playSound(String filename) async {
    try {
      await audioPlayer.stop();
      await audioPlayer.setVolume(soundVolume);
      if (soundVolume <= 0) return;
      await audioPlayer.play(AssetSource('sounds/$filename'));
    } catch (_) {
      // Missing audio must not interrupt gameplay.
    }
    // The effect must never silence the background music.
    await _keepMusicPlaying();
  }

  // ============================================================
  // TRACING INPUT
  // ============================================================

  void _handlePanStart(DragStartDetails details, double boardSize) {
    if (isPaused || showOptions || isGameOver || isPreview ||
        isMistakeReveal || isRoundComplete || !hasStarted || tracedPath.isEmpty) {
      return;
    }
    final cell = _positionToCell(details.localPosition, boardSize);
    if (cell == null) return;
    if (cell == tracedPath.last) setState(() => isDragging = true);
  }

  void _handlePanUpdate(DragUpdateDetails details, double boardSize) {
    if (!isDragging || isPaused || showOptions || isGameOver || isPreview ||
        isMistakeReveal || isRoundComplete || tracedPath.isEmpty) {
      return;
    }
    final cell = _positionToCell(details.localPosition, boardSize);
    if (cell == null || cell == tracedPath.last) return;
    final last = tracedPath.last;

    if (tracedPath.length >= 2 && cell == tracedPath[tracedPath.length - 2]) {
      setState(() {
        tracedPath.removeLast();
        totalMoves++;
      });
      return;
    }

    final distance = (cell.x - last.x).abs() + (cell.y - last.y).abs();
    if (distance != 1) return;
    if (!_isWalkable(cell)) {
      _triggerMistake();
      return;
    }
    setState(() {
      tracedPath.add(cell);
      totalMoves++;
    });
    if (cell == goal) _completeRound();
  }

  void _handlePanEnd(DragEndDetails details) {
    if (mounted) setState(() => isDragging = false);
  }

  Point<int>? _positionToCell(Offset position, double boardSize) {
    if (position.dx < 0 || position.dy < 0 ||
        position.dx >= boardSize || position.dy >= boardSize) return null;
    final cellSize = boardSize / mazeSize;
    final x = (position.dx / cellSize).floor();
    final y = (position.dy / cellSize).floor();
    if (x < 0 || y < 0 || x >= mazeSize || y >= mazeSize) return null;
    return Point<int>(x, y);
  }

  bool _isWalkable(Point<int> point) {
    if (point.x < 0 || point.y < 0 ||
        point.x >= mazeSize || point.y >= mazeSize) return false;
    return maze[point.y][point.x];
  }

  // ============================================================
  // MISTAKES / ROUND RESULTS
  // ============================================================

  void _triggerMistake() {
    if (isMistakeReveal || isPreview || isGameOver) return;
    mistakes++;
    _playSound('wrong.mp3');
    setState(() {
      isDragging = false;
      isPreview = true;
      isMistakeReveal = true;
      showTryAgain = true;
      secondsRemaining = 2;
    });
    _startTimer();
  }

  void _resolveFailedAttempt() {
    if (isGameOver || !isMistakeReveal) return;
    gameTimer?.cancel();
    lives = max(0, lives - 1);
    if (lives == 0) {
      _finishGame();
      return;
    }
    _prepareRound();
  }

  void _loseLifeForTimeout() {
    if (isGameOver) return;
    gameTimer?.cancel();
    _playSound('wrong.mp3');
    lives = max(0, lives - 1);
    if (lives == 0) {
      _finishGame();
      return;
    }
    _prepareRound();
  }

  void _completeRound() {
    if (isGameOver) return;
    gameTimer?.cancel();
    isRoundComplete = true;
    isDragging = false;
    roundsCompleted++;
    final timeBonus = secondsRemaining >= (solveTimeLimit ~/ 2) ? 10 : 0;
    xp += 20 + timeBonus;

    if (roundsCompleted >= maxRounds) {
      _playSound('level up.mp3');
      confettiController.play();
      _finishGame();
      return;
    }

    _playSound('correct.mp3');
    setState(() => currentRound++);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || isGameOver) return;
      _prepareRound();
    });
  }

  // ============================================================
  // PAUSE / RESTART / NAVIGATION
  // ============================================================

  void pauseGame() {
    if (isGameOver || isPaused || isRoundComplete) return;
    gameTimer?.cancel();
    audioPlayer.pause();
    musicPlayer.pause();
    setState(() {
      isPaused = true;
      showOptions = false;
    });
  }

  void resumeGame() {
    if (isGameOver || !isPaused) return;
    setState(() {
      isPaused = false;
      showOptions = false;
    });
    _startTimer();
    _resumeBackgroundMusic();
  }

  void restartGame() {
    gameTimer?.cancel();
    audioPlayer.stop();
    musicPlayer.stop();
    usedMazeSignatures.clear();
    setState(() {
      currentRound = 1;
      lives = startingLives;
      roundsCompleted = 0;
      totalMoves = 0;
      mistakes = 0;
      xp = 0;
      isPaused = false;
      isGameOver = false;
      isDragging = false;
      isRoundComplete = false;
      showOptions = false;
      isPreview = true;
      isMistakeReveal = false;
      showTryAgain = false;
    });
    _prepareRound();
    _startBackgroundMusic();
  }

  void goToMainMenu() {
    gameTimer?.cancel();
    musicPlayer.stop();
    audioPlayer.stop();
    Navigator.pop(context);
  }

  // ============================================================
  // SCORE / FIRESTORE
  // ============================================================

  String _gradeForAccuracy(double accuracy) {
    if (accuracy >= 90) return 'S';
    if (accuracy >= 80) return 'A';
    if (accuracy >= 70) return 'B';
    if (accuracy >= 60) return 'C';
    return 'D';
  }

  double get accuracy => (roundsCompleted / maxRounds) * 100;

  Future<void> _finishGame() async {
    if (isGameOver) return;
    gameTimer?.cancel();

    // Mark the game as over right away, so no sound effect can bring
    // the music back on the result screen.
    setState(() {
      isGameOver = true;
      isPaused = false;
      showOptions = false;
    });

    await musicPlayer.pause();

    final grade = _gradeForAccuracy(accuracy);
    try {
      // Player identity, so this score counts on the leaderboard.
      final identityFields = await ScoreIdentity.fields();

      await FirebaseFirestore.instance.collection('scores').add({
        ...identityFields,
        'level': 8,
        'levelName': 'Path Finder',
        'difficulty': widget.difficulty.label,
        'completed': roundsCompleted == maxRounds,
        'roundsCompleted': roundsCompleted,
        'totalRounds': maxRounds,
        'moves': totalMoves,
        'wallBumps': mistakes,
        'livesRemaining': lives,
        'xp': xp,
        'accuracy': accuracy,
        'grade': grade,
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Could not save Path Finder score: $error');
    }
  }

  // ============================================================
  // BUTTONS / APP BAR
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
        width: double.infinity,
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
            Text(label, style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
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
            child: const Text('Path Finder', style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )),
          ),
          if (!isGameOver)
            IconButton(
              onPressed: isRoundComplete ? null : pauseGame,
              icon: Icon(
                Icons.pause_circle_filled,
                color: isRoundComplete
                    ? Colors.amber.withValues(alpha: 0.4)
                    : Colors.amber,
                size: 32,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ============================================================
  // HUD
  // ============================================================

  Widget _buildHudCard({
    required IconData icon,
    required String title,
    required Widget value,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(title, style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    )),
                  ]),
                ),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: value),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hudText(String text, Color color) => Text(text, style: TextStyle(
    color: color,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  ));

  Widget _buildHearts() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(startingLives, (index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Icon(Icons.favorite_rounded,
          color: index < lives ? Colors.redAccent : Colors.white24,
          size: 17),
      )),
    );
  }

  Widget _buildHud() {
    final Color timeColor = isMistakeReveal
        ? Colors.redAccent
        : isPreview
            ? Colors.amber
            : (secondsRemaining <= 5 ? Colors.redAccent : Colors.cyanAccent);
    return Row(children: [
      _buildHudCard(icon: Icons.flag_rounded, title: 'ROUND',
        value: _hudText('$currentRound/$maxRounds', Colors.amber)),
      const SizedBox(width: 8),
      _buildHudCard(icon: Icons.timer_outlined, title: 'TIME',
        value: _hudText('${secondsRemaining}s', timeColor)),
      const SizedBox(width: 8),
      _buildHudCard(icon: Icons.bolt_rounded, title: 'XP',
        value: _hudText('$xp', Colors.greenAccent)),
      const SizedBox(width: 8),
      _buildHudCard(icon: Icons.favorite_rounded, title: 'LIVES',
        value: _buildHearts()),
    ]);
  }

  // ============================================================
  // GAMEPLAY BOARD
  // ============================================================

  Widget _buildGameplay() {
    final String title = isMistakeReveal
        ? 'TRY AGAIN!'
        : isPreview
            ? 'MEMORIZE THE MAZE'
            : 'TRACE TO THE FINISH';
    final Color titleColor = isMistakeReveal
        ? Colors.redAccent
        : isPreview
            ? Colors.amber
            : Colors.cyanAccent;
    final String hint = isMistakeReveal
        ? 'Study the revealed maze.'
        : isPreview
            ? 'Memorize the route before the maze hides.'
            : 'Drag from your avatar through the corridors to FINISH (F).';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        _buildHud(),
        const SizedBox(height: 12),
        Expanded(child: LayoutBuilder(builder: (context, area) {
          final double boardSize = max(0.0, min(
            min(area.maxWidth * 0.98, area.maxHeight - 90), 420.0));
          return Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: 1.2,
                ), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                _buildBoard(boardSize),
                const SizedBox(height: 10),
                Text(hint, style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ), textAlign: TextAlign.center),
              ]),
            ),
          );
        })),
      ]),
    );
  }

  Widget _buildBoard(double outerSize) {
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final double boardSize = max(0.0,
              min(constraints.maxWidth, constraints.maxHeight));
          return Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _handlePanStart(details, boardSize),
                onPanUpdate: (details) => _handlePanUpdate(details, boardSize),
                onPanEnd: _handlePanEnd,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MazePainter(
                            maze: maze,
                            size: mazeSize,
                            start: start,
                            goal: goal,
                            tracedPath: tracedPath,
                            revealMaze: isPreview || isMistakeReveal,
                            showTryAgain: showTryAgain,
                            wallColor: wallColor,
                            corridorColor: corridorColor,
                            hiddenColor: Colors.white.withValues(alpha: 0.14),
                            pathColor: Colors.cyanAccent,
                            mistakePathColor: Colors.redAccent,
                            startColor: startColor,
                            finishColor: finishColor,
                          ),
                        ),
                      ),
                      _buildStartAvatar(boardSize),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// The player's avatar, placed on the start cell of the maze.
  Widget _buildStartAvatar(double boardSize) {
    if (mazeSize <= 0) return const SizedBox.shrink();

    final double cellSize = boardSize / mazeSize;
    final double diameter = cellSize * 0.74;

    return Positioned(
      left: (start.x + 0.5) * cellSize - diameter / 2,
      top: (start.y + 0.5) * cellSize - diameter / 2,
      width: diameter,
      height: diameter,
      // Touches pass through, so tracing from the start still works.
      child: IgnorePointer(
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: PlayerAvatar(index: playerAvatar, size: diameter),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESULTS
  // ============================================================

  Widget _buildStatBadge(String title, String value) {
    return Column(children: [
      Text(title, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      )),
    ]);
  }

  Widget _buildResultScreen() {
    final String grade = _gradeForAccuracy(accuracy);
    final bool fullyCompleted = roundsCompleted == maxRounds;
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(fullyCompleted ? '🎉 LEVEL COMPLETE!' : '💔 OUT OF LIVES!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: fullyCompleted ? Colors.amber : Colors.redAccent,
                    letterSpacing: 1,
                  ), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(fullyCompleted
                    ? 'You remembered every maze!'
                    : 'Every attempt helps train your memory.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text('GRADE: $grade', style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                  )),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _buildStatBadge('⭐ XP', '+$xp'),
                  _buildStatBadge('🧭 Mazes', '$roundsCompleted/$maxRounds'),
                  _buildStatBadge('❤️ Lives', '$lives'),
                ]),
                const SizedBox(height: 10),
                Text('👣 Moves: $totalMoves   •   🧱 Wall bumps: $mistakes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
                const SizedBox(height: 20),
                _buildChunkyButton(
                  label: 'Play Again',
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
              ]),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )),
        child: SafeArea(
          child: Stack(children: [
            Column(children: [
              _buildCustomAppBar(),
              Expanded(child: isGameOver ? _buildResultScreen() : _buildGameplay()),
            ]),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green, Colors.blue, Colors.pink,
                  Colors.orange, Colors.purple, Colors.amber,
                ],
              ),
            ),
            // Pause menu + options screen (same structure as the Math game)
            if (isPaused)
              Positioned.fill(
                child: showOptions
                    ? _buildOptionsScreen()
                    : PauseMenu(
                        onResume: resumeGame,
                        onRestart: restartGame,
                        onOptions: _showGameOptions,
                        onMainMenu: goToMainMenu,
                      ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// 3D BUTTON WIDGET (same as the Math game)
// ============================================================

class _3DButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final Color shadowColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _3DButton({
    required this.text,
    this.icon,
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
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, _isPressed ? 0 : 5),
              blurRadius: 0,
            ),
          ],
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
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MAZE PAINTER
// ============================================================

class _MazePainter extends CustomPainter {
  final List<List<bool>> maze;
  final int size;
  final Point<int> start;
  final Point<int> goal;
  final List<Point<int>> tracedPath;
  final bool revealMaze;
  final bool showTryAgain;
  final Color wallColor;
  final Color corridorColor;
  final Color hiddenColor;
  final Color pathColor;
  final Color mistakePathColor;
  final Color startColor;
  final Color finishColor;

  _MazePainter({
    required this.maze,
    required this.size,
    required this.start,
    required this.goal,
    required this.tracedPath,
    required this.revealMaze,
    required this.showTryAgain,
    required this.wallColor,
    required this.corridorColor,
    required this.hiddenColor,
    required this.pathColor,
    required this.mistakePathColor,
    required this.startColor,
    required this.finishColor,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (size <= 0 || maze.length != size) return;
    final cellSize = canvasSize.width / size;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final rect = Rect.fromLTWH(
          x * cellSize, y * cellSize, cellSize, cellSize,
        );
        paint
          ..style = PaintingStyle.fill
          ..color = revealMaze
              ? (maze[y][x] ? corridorColor : wallColor)
              : hiddenColor;
        canvas.drawRect(rect, paint);
        paint
          ..color = !revealMaze
              ? Colors.white.withValues(alpha: 0.28)
              : maze[y][x]
                  ? const Color(0xFF3A0F52).withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, cellSize * 0.035);
        canvas.drawRect(rect, paint);
      }
    }

    if (tracedPath.isNotEmpty) {
      final pathOutlinePaint = Paint()
        ..color = const Color(0xFF14051F).withValues(alpha: 0.9)
        ..strokeWidth = cellSize * 0.68
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final pathPaint = Paint()
        ..color = showTryAgain ? mistakePathColor : pathColor
        ..strokeWidth = cellSize * 0.42
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      final first = tracedPath.first;
      path.moveTo((first.x + 0.5) * cellSize, (first.y + 0.5) * cellSize);
      for (int i = 1; i < tracedPath.length; i++) {
        final point = tracedPath[i];
        path.lineTo((point.x + 0.5) * cellSize, (point.y + 0.5) * cellSize);
      }
      // A dark outline keeps the bright route visible across both the
      // pale corridors and dark walls.
      canvas.drawPath(path, pathOutlinePaint);
      canvas.drawPath(path, pathPaint);
    }

    // Start: a green ring. The player's avatar is placed on top of it.
    final startCenter = Offset(
      (start.x + 0.5) * cellSize,
      (start.y + 0.5) * cellSize,
    );
    canvas.drawCircle(
      startCenter,
      cellSize * 0.46,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      startCenter,
      cellSize * 0.42,
      Paint()..color = startColor,
    );

    _drawMarker(canvas, goal, cellSize, finishColor, 'F');

    if (showTryAgain) {
      final textPainter = TextPainter(
        text: TextSpan(text: 'TRY AGAIN!', style: TextStyle(
          color: mistakePathColor,
          fontSize: min(22.0, cellSize * 1.2),
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
        )),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: canvasSize.width);
      textPainter.paint(canvas, Offset(
        (canvasSize.width - textPainter.width) / 2, 8,
      ));
    }
  }

  void _drawMarker(
    Canvas canvas,
    Point<int> point,
    double cellSize,
    Color color,
    String label,
  ) {
    final center = Offset(
      (point.x + 0.5) * cellSize,
      (point.y + 0.5) * cellSize,
    );
    canvas.drawCircle(center, cellSize * 0.41, Paint()..color = Colors.white);
    canvas.drawCircle(center, cellSize * 0.34, Paint()..color = color);
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: TextStyle(
        color: const Color(0xFF2E0854),
        fontSize: cellSize * 0.42,
        fontWeight: FontWeight.w900,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    ));
  }

  @override
  bool shouldRepaint(covariant _MazePainter oldDelegate) => true;
}