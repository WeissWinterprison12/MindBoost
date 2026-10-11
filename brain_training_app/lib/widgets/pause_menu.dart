import 'package:flutter/material.dart';

class PauseMenu extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onOptions;
  final VoidCallback onMainMenu;

  const PauseMenu({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onOptions,
    required this.onMainMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: GestureDetector(
        // Blocks taps from reaching the game underneath.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.88, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0).toDouble(),
                  child: Transform.scale(scale: value, child: child),
                );
              },
              child: _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4A0E4E),
            Color(0xFF811252),
            Color(0xFF2E0854),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.18),
            blurRadius: 30,
            spreadRadius: 3,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TITLE BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 2,
              ),
            ),
            child: const Text(
              '⏸  PAUSED',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Take a quick break!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 26),

          _PauseButton(
            text: 'RESUME',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF38EF7D),
            shadowColor: const Color(0xFF0C6B63),
            foreground: const Color(0xFF003816),
            onPressed: onResume,
          ),

          const SizedBox(height: 16),

          _PauseButton(
            text: 'RESTART',
            icon: Icons.refresh_rounded,
            color: const Color(0xFFFF8008),
            shadowColor: const Color(0xFF993D00),
            foreground: Colors.white,
            onPressed: onRestart,
          ),

          const SizedBox(height: 16),

          _PauseButton(
            text: 'OPTIONS',
            icon: Icons.settings_rounded,
            color: const Color(0xFF00A6FF),
            shadowColor: const Color(0xFF0052B4),
            foreground: Colors.white,
            onPressed: onOptions,
          ),

          const SizedBox(height: 16),

          _PauseButton(
            text: 'MAIN MENU',
            icon: Icons.home_rounded,
            color: const Color(0xFFFF4081),
            shadowColor: const Color(0xFF990033),
            foreground: Colors.white,
            onPressed: onMainMenu,
          ),
        ],
      ),
    );
  }
}

// CHUNKY 3D BUTTON (same style as the game buttons)
class _PauseButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final Color shadowColor;
  final Color foreground;
  final VoidCallback onPressed;

  const _PauseButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.shadowColor,
    required this.foreground,
    required this.onPressed,
  });

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
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
        width: double.infinity,
        height: 54,
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, _isPressed ? 1 : 5),
              blurRadius: 0,
            ),
            const BoxShadow(
              color: Colors.black38,
              offset: Offset(0, 6),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.foreground, size: 26),
            const SizedBox(width: 8),
            Text(
              widget.text,
              style: TextStyle(
                color: widget.foreground,
                fontSize: 18,
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