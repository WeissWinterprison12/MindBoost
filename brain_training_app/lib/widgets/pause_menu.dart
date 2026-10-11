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
      color: Colors.black.withOpacity(0.75),

      child: Center(
        child: Container(
          width: 320,

          padding: const EdgeInsets.all(28),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(24),

            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'PAUSED',

                style: TextStyle(
                  fontSize: 34,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // RESUME
              // ==================================================

              SizedBox(
                width: double.infinity,

                child:
                    ElevatedButton.icon(
                  onPressed: onResume,

                  icon: const Icon(
                    Icons.play_arrow,
                  ),

                  label: const Text(
                    'RESUME',

                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // RESTART
              // ==================================================

              SizedBox(
                width: double.infinity,

                child:
                    ElevatedButton.icon(
                  onPressed: onRestart,

                  icon: const Icon(
                    Icons.restart_alt,
                  ),

                  label: const Text(
                    'RESTART',

                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // OPTIONS
              // ==================================================

              SizedBox(
                width: double.infinity,

                child:
                    ElevatedButton.icon(
                  onPressed: onOptions,

                  icon: const Icon(
                    Icons.settings,
                  ),

                  label: const Text(
                    'OPTIONS',

                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // MAIN MENU
              // ==================================================

              SizedBox(
                width: double.infinity,

                child:
                    ElevatedButton.icon(
                  onPressed: onMainMenu,

                  icon: const Icon(
                    Icons.home,
                  ),

                  label: const Text(
                    'MAIN MENU',

                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}