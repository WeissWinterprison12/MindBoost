import 'package:flutter/material.dart';

/// Options screen with the same look as [PauseMenu]:
/// dark overlay, purple card with a gold border, a gold title pill,
/// and chunky 3D buttons.
class OptionsMenu extends StatelessWidget {
  final double musicVolume;
  final ValueChanged<double> onMusicVolumeChanged;

  // Optional: leave these out to show only the music slider
  // (the menu screens have no sound effects).
  final double? soundVolume;
  final ValueChanged<double>? onSoundVolumeChanged;

  final VoidCallback onBack;

  final String subtitle;
  final String backLabel;
  final IconData backIcon;

  const OptionsMenu({
    super.key,
    required this.musicVolume,
    required this.onMusicVolumeChanged,
    this.soundVolume,
    this.onSoundVolumeChanged,
    required this.onBack,
    this.subtitle = 'Adjust your game audio',
    this.backLabel = 'BACK',
    this.backIcon = Icons.arrow_back_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
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
                child: Transform.scale(
                  scale: value,
                  child: child,
                ),
              );
            },
            child: _buildCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
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
          // TITLE
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 2,
              ),
            ),
            child: const Text(
              '⚙️  OPTIONS',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 24),

          // MUSIC VOLUME
          _buildVolumeTile(
            context,
            title: '🎵 Background Music',
            value: musicVolume,
            onChanged: onMusicVolumeChanged,
          ),

          // SOUND EFFECTS VOLUME (only when provided)
          if (soundVolume != null && onSoundVolumeChanged != null) ...[
            const SizedBox(height: 16),
            _buildVolumeTile(
              context,
              title: '🔊 Sound Effects',
              value: soundVolume!,
              onChanged: onSoundVolumeChanged!,
            ),
          ],

          const SizedBox(height: 24),

          // BACK
          _OptionsButton(
            text: backLabel,
            icon: backIcon,
            color: const Color(0xFFFFD700),
            shadowColor: const Color(0xFFB8860B),
            foreground: const Color(0xFF3B0B46),
            onPressed: onBack,
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeTile(
    BuildContext context, {
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final int percentage = (value * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
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
              value: value.clamp(0.0, 1.0).toDouble(),
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '$percentage%',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// CHUNKY 3D BUTTON (same style as the buttons in the pause menu)
class _OptionsButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final Color shadowColor;
  final Color foreground;
  final VoidCallback onPressed;

  const _OptionsButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.shadowColor,
    required this.foreground,
    required this.onPressed,
  });

  @override
  State<_OptionsButton> createState() => _OptionsButtonState();
}

class _OptionsButtonState extends State<_OptionsButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
        width: double.infinity,
        height: 54,
        transform: Matrix4.translationValues(
          0,
          _isPressed ? 4 : 0,
          0,
        ),
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
            Icon(
              widget.icon,
              color: widget.foreground,
              size: 26,
            ),
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
