import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/level_select_screen.dart';
import 'screens/auth_screen.dart';
import 'services/menu_music.dart';
import 'widgets/menu_options.dart';

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
          seedColor: const Color(0xFF811252),
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

  void _startGame(BuildContext context) {
    // Web browsers block audio until the first tap, so make sure the
    // music is running now (does nothing if it is already playing).
    MenuMusic.instance.start();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Not signed in: open the authentication screen.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
      );
    } else {
      // Already signed in: go straight to level selection.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LevelSelectScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              // TOP TITLE BADGE
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
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
                        Icons.star_rounded,
                        color: Color(0xFFFFD700),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'BRAIN ARENA',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFD700),
                        size: 22,
                      ),
                    ],
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
                          color: const Color(0xFFFF8008).withOpacity(0.6),
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
                        'assets/images/mindboost_logo.jpg',
                        fit: BoxFit.cover,
                        // If the image can't be loaded, show the brain emoji.
                        errorBuilder: (context, error, stackTrace) {
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
                    shaderCallback: (bounds) => const LinearGradient(
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Leaderboard coming soon!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: Colors.purple.shade900,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
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
