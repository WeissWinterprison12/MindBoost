import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/level_select_screen.dart';
import 'screens/auth_screen.dart';
import 'services/menu_music.dart';
import 'widgets/menu_options.dart';
import 'screens/leaderboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());

  // Start the menu music as soon as the app opens. It keeps playing
  // through the level select screen and only pauses inside a game.
  MenuMusic.instance.start();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MindBoost',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(  
          seedColor: const Color(0xFF806BC4),
        ),
        useMaterial3: true,
      ),
      navigatorObservers: [menuRouteObserver],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // START GAME
  // If a player profile already exists (saved on this device or in
  // Firebase), go straight to level select. Otherwise create a player.
  Future<void> _startGame(BuildContext context) async {
    // Web browsers block audio until the first tap, so make sure the
    // music is running now (does nothing if it is already playing).
    MenuMusic.instance.start();

    var hasProfile = false;

    // 1) Check the locally saved profile first (works offline).
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('player_username');
      hasProfile = savedName != null && savedName.trim().isNotEmpty;
    } catch (e) {
      debugPrint('Could not read local profile: $e');
    }

    // 2) Fall back to the Firebase account, if there is one.
    if (!hasProfile) {
      final name = FirebaseAuth.instance.currentUser?.displayName;
      hasProfile = name != null && name.trim().isNotEmpty;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            hasProfile ? const LevelSelectScreen() : const AuthScreen(),
      ),
    );
  }

  // HOW TO PLAY SHEET
  void _showHowToPlay(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'HOW TO PLAY',
                  style: TextStyle(
                    color: Color(0xFF4A0E4E),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                const Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _HowToStep(
                          number: 1,
                          icon: Icons.person_rounded,
                          title: 'Create your player',
                          text:
                              'Tap START GAME, pick an avatar and a player name. You only do this once.',
                        ),
                        _HowToStep(
                          number: 2,
                          icon: Icons.grid_view_rounded,
                          title: 'Pick a puzzle',
                          text:
                              'Choose any level on the Level Select screen. Each one trains a different skill: math, memory, logic, words and more.',
                        ),
                        _HowToStep(
                          number: 3,
                          icon: Icons.timer_rounded,
                          title: 'Think fast, answer smart',
                          text:
                              'Read the instructions at the start of each game and answer as accurately as you can.',
                        ),
                        _HowToStep(
                          number: 4,
                          icon: Icons.star_rounded,
                          title: 'Earn stars',
                          text:
                              'Play well to earn up to 3 stars per level. Replay levels to improve your score!',
                        ),
                        _HowToStep(
                          number: 5,
                          icon: Icons.settings_rounded,
                          title: 'Make it yours',
                          text:
                              'Use OPTIONS to change the music volume, and tap your profile to edit your name or avatar.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF811252),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text(
                      'GOT IT!',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7564B8), // Soft violet at the top
              Color(0xFF806BC4), // Lighter lavender violet
              Color(0xFF5B4A98), // Soft deep violet at the bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // TOP "HOW TO PLAY" BUTTON
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () => _showHowToPlay(context),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.help_outline_rounded,
                                      color: Color(0xFFFFD700),
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'HOW TO PLAY',
                                      style: TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // CENTER HERO SECTION
                        Column(
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFFFD700),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF8008)
                                        .withOpacity(0.6),
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                  ),
                                  const BoxShadow(
                                    color: Colors.black38,
                                    offset: Offset(0, 8),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/mindboostlogo.jpg',
                                  fit: BoxFit.cover,
                                  // If the image can't be loaded, show the brain emoji.
                                  errorBuilder:
                                      (context, error, stackTrace) {
                                    return const Center(
                                      child: Text(
                                        '🧠',
                                        style: TextStyle(fontSize: 70),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

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
                              child: const Text(
                                'MindBoost',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      offset: Offset(3, 4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Level Up Your Brainpower! 🚀',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ACTION BUTTONS
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 30,
                          ),
                          child: Column(
                            children: [
                              _3DGameButton(
                                text: 'START GAME',
                                icon: Icons.play_arrow_rounded,
                                buttonColor: const Color(0xFF38EF7D),
                                shadowColor: const Color(0xFF0C6B63),
                                textColor: const Color(0xFF003816),
                                onPressed: () => _startGame(context),
                              ),

                              const SizedBox(height: 14),

                              _3DGameButton(
                                text: 'LEADERBOARD',
                                icon: Icons.emoji_events_rounded,
                                buttonColor: const Color(0xFFFF8008),
                                shadowColor: const Color(0xFF993D00),
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LeaderboardScreen(),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 14),

                              _3DGameButton(
                                text: 'OPTIONS',
                                icon: Icons.settings_rounded,
                                buttonColor: const Color(0xFF00A6FF),
                                shadowColor: const Color(0xFF0052B4),
                                textColor: Colors.white,
                                onPressed: () => showMenuOptions(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// One row inside the "How to play" sheet.
class _HowToStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String text;

  const _HowToStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF1DDF4),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 2,
              ),
            ),
            child: Icon(icon, color: const Color(0xFF811252), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: const TextStyle(
                    color: Color(0xFF4A0E4E),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13.5,
                    height: 1.35,
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

class _3DGameButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color buttonColor;
  final Color shadowColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _3DGameButton({
    required this.text,
    required this.icon,
    required this.buttonColor,
    required this.shadowColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  State<_3DGameButton> createState() => _3DGameButtonState();
}

class _3DGameButtonState extends State<_3DGameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 62,
        transform: Matrix4.translationValues(
          0,
          _isPressed ? 5 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: widget.buttonColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, _isPressed ? 1 : 6),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 8),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: widget.textColor,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(
              widget.text,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}