import 'package:flutter/material.dart';

import '../services/menu_music.dart';
import 'options_menu.dart';

/// Opens the Options screen used by the main menu and the level select
/// screen. It controls the menu music volume, and the choice is saved,
/// so it is still the same the next time the app is opened.
Future<void> showMenuOptions(BuildContext context) async {
  // Make sure the saved volume has been read before showing the slider.
  await MenuMusic.instance.loadVolume();

  if (!context.mounted) return;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Options',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return ValueListenableBuilder<double>(
        valueListenable: MenuMusic.instance.volumeNotifier,
        builder: (context, volume, child) {
          return OptionsMenu(
            subtitle: 'Adjust the music volume',
            musicVolume: volume,
            onMusicVolumeChanged: (value) {
              MenuMusic.instance.setVolume(value);
            },
            backLabel: 'CLOSE',
            backIcon: Icons.close_rounded,
            onBack: () {
              Navigator.of(dialogContext).pop();
            },
          );
        },
      );
    },
  );
}
