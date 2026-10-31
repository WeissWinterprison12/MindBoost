import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';
import '../widgets/player_avatar.dart';
import '../models/game_difficulty.dart';

import '../game/math_game.dart';
import '../game/science_puzzle.dart';
import '../game/memory_match.dart';
import '../game/pattern_sequence.dart';
import '../game/tile_matrix.dart';
import '../game/case_detective.dart';
import '../game/path_finder.dart';
import '../game/word_quest.dart';
import '../services/menu_music.dart';
import '../widgets/game_loading_screen.dart';
import '../widgets/menu_options.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with RouteAware {
  @override
  void initState() {
    super.initState();
    _syncLocalProfileToFirebase();
  }

  Future<void> _syncLocalProfileToFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('player_username')?.trim();
      final savedAvatar = prefs.getInt('player_avatar') ?? 0;

      final username = savedName != null && savedName.isNotEmpty
          ? savedName
          : 'Guest Player';

      final auth = FirebaseAuth.instance;
      var user = auth.currentUser;

      if (user == null) {
        final credential = await auth.signInAnonymously();
        user = credential.user;
      }

      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'playerId': user.uid,
        'username': username,
        'avatar': savedAvatar.clamp(0, kAvatarCount - 1).toInt(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) setState(() {});
      debugPrint('Player profile synced to Firebase.');
    } catch (error) {
      debugPrint('Profile sync skipped: $error');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      menuRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    MenuMusic.instance.pause();
  }

  @override
  void didPopNext() {
    MenuMusic.instance.restart();
  }

  @override
  void dispose() {
    menuRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF7564B8),
              Color(0xFF806BC4),
              Color(0xFF5B4A98),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _build3DButton(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 2,
                        ),
                      ),
                      child: const Text(
                        'LEVEL SELECT',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    PlayerProfileButton(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [
                                Color(0xFFFFF176),
                                Color(0xFFFF8A65),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: Image.asset(
                                      'assets/images/mindboostlogo.jpg',
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.image_not_supported_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'MindBoost',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          offset: Offset(2, 4),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Text(
                            'Pick your puzzle arena!',
                            style: TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _build3DButton(
                      onTap: () => showMenuOptions(context),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            offset: Offset(0, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '18/18',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    GameLevelCard(
                      levelNum: '1',
                      title: 'Math Challenge',
                      subtitle: 'Speed & Accuracy',
                      icon: '🔢',
                      gradientColors: const [
                        Color(0xFF00C6FF),
                        Color(0xFF0072FF),
                      ],
                      borderColor: const Color(0xFF0052B4),
                      starsEarned: 1,
                      unlocked: true,
                      page: const MathGame(),
                    ),
                    GameLevelCard(
                      levelNum: '2',
                      title: 'Science Puzzle',
                      subtitle: 'Memory & Observation',
                      icon: '🔬',
                      gradientColors: const [
                        Color(0xFF11998E),
                        Color(0xFF38EF7D),
                      ],
                      borderColor: const Color(0xFF0C6B63),
                      starsEarned: 1,
                      unlocked: true,
                      page: const SciencePuzzle(),
                    ),
                    GameLevelCard(
                      levelNum: '3',
                      title: 'Memory Match',
                      subtitle: 'Focus & Attention',
                      icon: '🧩',
                      gradientColors: const [
                        Color(0xFF8E2DE2),
                        Color(0xFF4A00E0),
                      ],
                      borderColor: const Color(0xFF330099),
                      starsEarned: 2,
                      unlocked: true,
                      page: const MemoryMatch(),
                    ),
                    GameLevelCard(
                      levelNum: '4',
                      title: 'Pattern Logic',
                      subtitle: 'Logic & Recall',
                      icon: '🧠',
                      gradientColors: const [
                        Color(0xFFFF8008),
                        Color(0xFFFFC837),
                      ],
                      borderColor: const Color(0xFFC76000),
                      starsEarned: 2,
                      unlocked: true,
                      page: const PatternSequence(),
                    ),
                    GameLevelCard(
                      levelNum: '5',
                      title: 'Tile Matrix',
                      subtitle: 'Find the Mismatch',
                      icon: '🎯',
                      gradientColors: const [
                        Color(0xFFF7971E),
                        Color(0xFFFFD200),
                      ],
                      borderColor: const Color(0xFFB86B00),
                      starsEarned: 2,
                      unlocked: true,
                      page: const MemoryMatrix(),
                    ),
                    GameLevelCard(
                      levelNum: '6',
                      title: 'Case Detective',
                      subtitle: 'Solve the Mystery',
                      icon: '🔎',
                      gradientColors: const [
                        Color(0xFF654EA3),
                        Color(0xFFEAAFC8),
                      ],
                      borderColor: const Color(0xFF493078),
                      starsEarned: 3,
                      unlocked: true,
                      page: const LogicDetective(),
                    ),
                    GameLevelCard(
                      levelNum: '7',
                      title: 'Word Quest',
                      subtitle: 'Four Pics, One Word',
                      icon: '🧩',
                      gradientColors: const [
                        Color(0xFF7C83FF),
                        Color(0xFF5146D8),
                      ],
                      borderColor: const Color(0xFF3730A3),
                      starsEarned: 3,
                      unlocked: true,
                      page: const WordQuestGame(),
                    ),
                    GameLevelCard(
                      levelNum: '8',
                      title: 'Path Finder',
                      subtitle: 'Navigate the Maze',
                      icon: '🧭',
                      gradientColors: const [
                        Color(0xFF39216C),
                        Color(0xFF160B36),
                      ],
                      borderColor: const Color(0xFF64E7FF),
                      starsEarned: 3,
                      unlocked: true,
                      page: const PathFinder(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _build3DButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF4081),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF990033),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PlayerProfileButton extends StatelessWidget {
  PlayerProfileButton({super.key});

  String _getUsername(User user, Map<String, dynamic>? data) {
    final savedUsername = data?['username'];
    if (savedUsername is String && savedUsername.trim().isNotEmpty) {
      return savedUsername.trim();
    }

    final displayName = user.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Player';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          final prefs = snapshot.data;
          final savedName = prefs?.getString('player_username');
          final savedAvatar = prefs?.getInt('player_avatar') ?? 0;
          return _buildProfile(
            context,
            username: savedName != null && savedName.trim().isNotEmpty
                ? savedName.trim()
                : 'Guest Player',
            avatar: savedAvatar.clamp(0, kAvatarCount - 1),
            user: null,
          );
        },
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final username = _getUsername(user, data);
        final avatarRaw = data?['avatar'];
        final avatar = avatarRaw is int ? avatarRaw : 0;
        return _buildProfile(
          context,
          username: username,
          avatar: avatar,
          user: user,
        );
      },
    );
  }

  Widget _buildProfile(
    BuildContext context, {
    required String username,
    required int avatar,
    required User? user,
  }) {
    return Tooltip(
      message: 'Account settings',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _showAccountSettings(
            context,
            user: user,
            username: username,
            avatar: avatar,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD700),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: Colors.white,
                  child: PlayerAvatar(index: avatar, size: 46),
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountSettings(
    BuildContext context, {
    required User? user,
    required String username,
    required int avatar,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 22),
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFF1DDF4),
                  child: PlayerAvatar(index: avatar, size: 76),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ACCOUNT SETTINGS',
                  style: TextStyle(
                    color: Color(0xFF4A0E4E),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  username,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF811252),
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user == null
                      ? 'Playing as a guest'
                      : 'Your player profile and progress',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF811252),
                  ),
                  title: const Text('Player username'),
                  subtitle: Text(username),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFF811252),
                  ),
                  title: const Text('MindBoost Player'),
                  subtitle: Text(
                    user == null
                        ? 'Guest account'
                        : 'Signed in to save your progress',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('EDIT PROFILE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF811252),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AuthScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('CANCEL'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GameLevelCard extends StatefulWidget {
  final String levelNum;
  final String title;
  final String subtitle;
  final String icon;
  final List<Color> gradientColors;
  final Color borderColor;
  final int starsEarned;
  final bool unlocked;
  final Widget page;

  const GameLevelCard({
    super.key,
    required this.levelNum,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.borderColor,
    required this.starsEarned,
    required this.unlocked,
    required this.page,
  });

  @override
  State<GameLevelCard> createState() => _GameLevelCardState();
}

class _GameLevelCardState extends State<GameLevelCard> {
  bool _isPressed = false;

  Future<void> _openDifficultySelection() async {
    if (!widget.unlocked) return;

    final selectedDifficulty = await showModalBottomSheet<GameDifficulty>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF806BC4), Color(0xFF51418F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mindboostlogo.jpg',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.white,
                          size: 30,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'SELECT DIFFICULTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                _buildDifficultyButton(
                  context: sheetContext,
                  difficulty: GameDifficulty.easy,
                  title: 'EASY',
                  description: 'Relax and learn at your own pace',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  color: const Color(0xFF43C77A),
                ),
                const SizedBox(height: 12),
                _buildDifficultyButton(
                  context: sheetContext,
                  difficulty: GameDifficulty.medium,
                  title: 'MEDIUM',
                  description: 'A balanced challenge',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFFFA726),
                ),
                const SizedBox(height: 12),
                _buildDifficultyButton(
                  context: sheetContext,
                  difficulty: GameDifficulty.hard,
                  title: 'HARD',
                  description: 'Test your skills with a greater challenge',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFEF5350),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedDifficulty == null) return;

    // Pass the selected difficulty to games that support it.
    final Widget selectedGame = widget.levelNum == '1'
        ? MathGame(difficulty: selectedDifficulty)
        : widget.levelNum == '2'
            ? SciencePuzzle(difficulty: selectedDifficulty)
            : widget.levelNum == '3'
                ? MemoryMatch(difficulty: selectedDifficulty)
                : widget.levelNum == '4'
                    ? PatternSequence(difficulty: selectedDifficulty)
                    : widget.page;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameLoadingScreen(
          levelTitle: widget.title,
          nextScreen: selectedGame,
        ),
      ),
    );
  }

  Widget _buildDifficultyButton({
    required BuildContext context,
    required GameDifficulty difficulty,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.pop(context, difficulty),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withOpacity(0.9),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _openDifficultySelection();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 18),
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.borderColor,
              offset: Offset(0, _isPressed ? 2 : 7),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 8),
              blurRadius: 10,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.icon,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'LEVEL ${widget.levelNum}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black38,
                            offset: Offset(1, 2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Difficulty: ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        ...List.generate(widget.starsEarned, (index) {
                          return const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFD700),
                            size: 18,
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          widget.starsEarned == 1
                              ? 'Easy'
                              : widget.starsEarned == 2
                                  ? 'Medium'
                                  : 'Hard',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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