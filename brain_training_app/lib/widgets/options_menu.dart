import 'package:flutter/material.dart';

/// Options screen with the same look as [PauseMenu]. Used by the menu
/// screens and by every game.
class OptionsMenu extends StatelessWidget {
  final double musicVolume;
  final ValueChanged<double> onMusicVolumeChanged;

  /// Tapping the music icon. Leave null to make the icon non-clickable.
  final VoidCallback? onMusicMuteToggle;

  // Optional: leave these out to show only the music slider
  // (the menu screens have no sound effects).
  final double? soundVolume;
  final ValueChanged<double>? onSoundVolumeChanged;
  final VoidCallback? onSoundMuteToggle;

  /// Shows the "MUTE ALL SOUNDS" button when provided.
  final VoidCallback? onMuteAll;
  final bool allMuted;

  final VoidCallback onBack;

  final String subtitle;
  final String backLabel;
  final IconData backIcon;

  const OptionsMenu({
    super.key,
    required this.musicVolume,
    required this.onMusicVolumeChanged,
    this.onMusicMuteToggle,
    this.soundVolume,
    this.onSoundVolumeChanged,
    this.onSoundMuteToggle,
    this.onMuteAll,
    this.allMuted = false,
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
                child: Transform.scale(scale: value, child: child),
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
        border: Border.all(color: const Color(0xFFFFD700), width: 3),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
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

          _buildVolumeTile(
            context,
            title: 'Background Music',
            icon: Icons.music_note_rounded,
            mutedIcon: Icons.music_off_rounded,
            value: musicVolume,
            onChanged: onMusicVolumeChanged,
            onIconTap: onMusicMuteToggle,
          ),

          if (soundVolume != null && onSoundVolumeChanged != null) ...[
            const SizedBox(height: 16),
            _buildVolumeTile(
              context,
              title: 'Sound Effects',
              icon: Icons.volume_up_rounded,
              mutedIcon: Icons.volume_off_rounded,
              value: soundVolume!,
              onChanged: onSoundVolumeChanged!,
              onIconTap: onSoundMuteToggle,
            ),
          ],

          const SizedBox(height: 24),

          if (onMuteAll != null) ...[
            _OptionsButton(
              text: allMuted ? 'UNMUTE' : 'MUTE',
              icon: allMuted
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: allMuted
                  ? const Color(0xFFE53935)
                  : const Color(0xFFFF8008),
              shadowColor: allMuted
                  ? const Color(0xFF8E1B1B)
                  : const Color(0xFF993D00),
              foreground: Colors.white,
              onPressed: onMuteAll!,
            ),
            const SizedBox(height: 16),
          ],

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
    required IconData icon,
    required IconData mutedIcon,
    required double value,
    required ValueChanged<double> onChanged,
    required VoidCallback? onIconTap,
  }) {
    final int percentage = (value * 100).round();
    final bool muted = value <= 0.0;
    final Color accent = muted ? Colors.redAccent : const Color(0xFFFFD700);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onIconTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: muted
                        ? Colors.redAccent
                        : Colors.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: muted ? Colors.white : const Color(0xFFFFD700),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    muted ? mutedIcon : icon,
                    color: muted ? Colors.white : const Color(0xFFFFD700),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
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

// CHUNKY 3D BUTTON (unchanged)
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
            Flexible(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: widget.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}