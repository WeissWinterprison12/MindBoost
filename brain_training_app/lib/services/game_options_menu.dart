import 'package:flutter/material.dart';

import 'game_audio.dart';
import '../widgets/options_menu.dart';

/// The in-game options screen. It shares [OptionsMenu] with the menus.
class GameOptionsMenu extends StatelessWidget {
  final GameAudio audio;
  final VoidCallback onBack;

  const GameOptionsMenu({
    super.key,
    required this.audio,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        return OptionsMenu(
          musicVolume: audio.musicVolume,
          onMusicVolumeChanged: audio.setMusicVolume,
          onMusicMuteToggle: audio.toggleMusicMute,
          soundVolume: audio.soundVolume,
          onSoundVolumeChanged: audio.setSoundVolume,
          onSoundMuteToggle: audio.toggleSoundMute,
          onMuteAll: audio.toggleMuteAll,
          allMuted: audio.allMuted,
          onBack: onBack,
        );
      },
    );
  }
}