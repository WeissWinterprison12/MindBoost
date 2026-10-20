import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'auth_screen.dart';

import '../game/math_game.dart';
import '../game/science_puzzle.dart';
import '../game/memory_match.dart';
import '../game/pattern_sequence.dart';
import '../game/memory_matrix.dart';
import '../game/logic_detective.dart';
import '../game/path_finder.dart';
import '../game/word_quest.dart';
import '../services/menu_music.dart';
import '../widgets/game_loading_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with RouteAware {
  // ============================================================
  // MENU MUSIC
  // The music keeps playing here, pauses while a game is open, and
  // starts again when the player comes back to this screen.
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      menuRouteObserver.subscribe(this, route);
    }
  }

  // A game (or its loading screen) was opened on top of this screen.
  @override
  void didPushNext() {
    MenuMusic.instance.pause();
  }

  // The game was closed and this screen is visible again.
  @override
  void didPopNext() {
    MenuMusic.instance.restart();
  }

  @override
  void dispose() {
    menuRouteObserver.unsubscribe(this);
    super.dispose();
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER ROW: back arrow, LEVEL SELECT, profile
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
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

              // TITLE (left) + STARS (right, under profile)
              Padding(
                // Right padding is 24 so the badge lines up with the
                // profile avatar (16 screen padding + 8 button padding).
                padding: const EdgeInsets.fromLTRB(20, 0, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
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
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '🧠 MindBoost',
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

              // GAME LEVELS
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    25,
                  ),
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
                      starsEarned: 3,
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
                      starsEarned: 3,
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
                      starsEarned: 3,
                      unlocked: true,
                      page: const MemoryMatch(),
                    ),

                    // Pattern Logic + Sequence Recall merged into one level.
                    GameLevelCard(
                      levelNum: '4',
                      title: 'Pattern & Sequence',
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
                      title: 'Memory Matrix',
                      subtitle: 'Find the Mismatch',
                      icon: '🎯',
                      gradientColors: const [
                        Color(0xFFF7971E),
                        Color(0xFFFFD200),
                      ],
                      borderColor: const Color(0xFFB86B00),
                      starsEarned: 0,
                      unlocked: true,
                      page: const MemoryMatrix(),
                    ),

                    GameLevelCard(
                      levelNum: '6',
                      title: 'Logic Detective',
                      subtitle: 'Solve the Mystery',
                      icon: '🔎',
                      gradientColors: const [
                        Color(0xFF654EA3),
                        Color(0xFFEAAFC8),
                      ],
                      borderColor: const Color(0xFF493078),
                      starsEarned: 0,
                      unlocked: true,
                      page: const LogicDetective(),
                    ),

                    GameLevelCard(
                      levelNum: '7',
                      title: 'Path Finder',
                      subtitle: 'Navigate the Maze',
                      icon: '🧭',
                      gradientColors: const [
                        Color(0xFF39216C),
                        Color(0xFF160B36),
                      ],
                      borderColor: const Color(0xFF64E7FF),
                      starsEarned: 0,
                      unlocked: true,
                      page: const PathFinder(),
                    ),

                    GameLevelCard(
                      levelNum: '8',
                      title: 'Word Quest',
                      subtitle: 'Four Pics, One Word',
                      icon: '🧩',
                      gradientColors: const [
                        Color(0xFF7C83FF),
                        Color(0xFF5146D8),
                      ],
                      borderColor: const Color(0xFF3730A3),
                      starsEarned: 0,
                      unlocked: true,
                      page: const WordQuestGame(),
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

// ============================================================
// PLAYER PROFILE BUTTON
// Displays the provider's profile photo and saved username.
// ============================================================

class PlayerProfileButton extends StatelessWidget {
  PlayerProfileButton({super.key});

  String _getUsername(
    User user,
    Map<String, dynamic>? data,
  ) {
    final savedUsername = data?['username'];

    if (savedUsername is String &&
        savedUsername.trim().isNotEmpty) {
      return savedUsername.trim();
    }

    final displayName = user.displayName;

    if (displayName != null &&
        displayName.trim().isNotEmpty) {
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
      return _buildProfile(
        context,
        username: 'Guest Player',
        photoUrl: null,
        user: null,
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        final username = _getUsername(user, data);

        final savedPhoto = data?['photoUrl'];

        final photoUrl =
            user.photoURL ??
            (savedPhoto is String ? savedPhoto : null);

        return _buildProfile(
          context,
          username: username,
          photoUrl: photoUrl,
          user: user,
        );
      },
    );
  }

  Widget _buildProfile(
    BuildContext context, {
    required String username,
    required String? photoUrl,
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
            photoUrl: photoUrl,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
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
                  child: ClipOval(
                    child: _profileImage(
                      photoUrl,
                      46,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 110,
                ),
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

  Widget _profileImage(
    String? photoUrl,
    double size,
  ) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return Icon(
        Icons.person,
        size: size * 0.65,
        color: const Color(0xFF811252),
      );
    }

    return Image.network(
      photoUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.person,
          size: size * 0.65,
          color: const Color(0xFF811252),
        );
      },
    );
  }

  void _showAccountSettings(
    BuildContext context, {
    required User? user,
    required String username,
    required String? photoUrl,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            28,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBFF),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // BOTTOM SHEET HANDLE
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 22),

                // PROFILE PICTURE
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFF1DDF4),
                  child: ClipOval(
                    child: _profileImage(
                      photoUrl,
                      76,
                    ),
                  ),
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
                  user?.email ?? 'Playing as a guest',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 8),

                // USERNAME
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF811252),
                  ),
                  title: const Text('Player username'),
                  subtitle: Text(username),
                ),

                // ACCOUNT STATUS
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

                // SIGN OUT
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      user == null
                          ? 'EXIT GUEST MODE'
                          : 'SIGN OUT',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF811252),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(sheetContext);

                      try {
                        final providers = user
                                ?.providerData
                                .map((provider) =>
                                    provider.providerId)
                                .toSet() ??
                            <String>{};

                        // Sign out of Firebase first.
                        await FirebaseAuth.instance.signOut();

                        // Sign out of Google if used.
                        if (providers.contains('google.com')) {
                          try {
                            await GoogleSignIn.instance.signOut();
                          } catch (e) {
                            debugPrint(
                              'Google sign-out notice: $e',
                            );
                          }
                        }

                        // Sign out of Facebook if used.
                        if (providers.contains('facebook.com')) {
                          try {
                            await FacebookAuth.instance.logOut();
                          } catch (e) {
                            debugPrint(
                              'Facebook logout notice: $e',
                            );
                          }
                        }

                        if (!context.mounted) return;

                        // Return to authentication and clear
                        // the previous navigation stack.
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const AuthScreen(),
                          ),
                          (route) => false,
                        );
                      } catch (e) {
                        debugPrint(
                          'Account sign-out failed: $e',
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Unable to sign out. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                  },
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

// ============================================================
// GAME LEVEL CARD
// ============================================================

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);

        if (!widget.unlocked) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameLoadingScreen(
              levelTitle: widget.title,
              nextScreen: widget.page,
            ),
          ),
        );
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 18),
        transform: Matrix4.translationValues(
          0,
          _isPressed ? 4 : 0,
          0,
        ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
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
                      children: List.generate(3, (index) {
                        return Icon(
                          index < widget.starsEarned
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < widget.starsEarned
                              ? const Color(0xFFFFD700)
                              : Colors.white54,
                          size: 20,
                        );
                      }),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.borderColor,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  widget.unlocked
                      ? Icons.play_arrow_rounded
                      : Icons.lock_rounded,
                  color: widget.borderColor,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOCKED LEVEL CARD
// ============================================================

class LockedLevelCard extends StatelessWidget {
  final String levelNum;
  final String title;
  final String subtitle;

  const LockedLevelCard({
    super.key,
    required this.levelNum,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white24,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.lock_rounded,
                color: Colors.white54,
                size: 30,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVEL $levelNum',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
