import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../services/menu_music.dart';

class GameTutorial {
  static const _onboardingKey = 'onboarding_done';

  static final ValueNotifier<bool> onboarding = ValueNotifier<bool>(false);

  static Future<void> loadOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    onboarding.value = !(prefs.getBool(_onboardingKey) ?? false);
  }

  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    onboarding.value = false;
  }

  static Future<bool?> showVideo(
    BuildContext context, {
    required String levelNum,
    required String title,
    bool guided = false,
  }) async {

    MenuMusic.instance.pause();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TutorialVideoDialog(
        title: title,
        guided: guided,
        assetPath: 'assets/videos/tutorials/level_$levelNum.mp4',
      ),
    );

    MenuMusic.instance.restart();

    if (result == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutorial video coming soon!')),
      );
    }
    return result;
  }
}

class _TutorialVideoDialog extends StatefulWidget {
  final String title;
  final String assetPath;
  final bool guided;

  const _TutorialVideoDialog({
    required this.title,
    required this.assetPath,
    required this.guided,
  });

  @override
  State<_TutorialVideoDialog> createState() => _TutorialVideoDialogState();
}

class _TutorialVideoDialogState extends State<_TutorialVideoDialog> {
  late final VideoPlayerController _controller;
  Timer? _hintTimer;

  bool _ready = false;
  bool _hasStartedPlaying = false;
  bool _showCloseHint = false;

  bool get _canClose => !widget.guided || _showCloseHint;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath);
    _controller.addListener(_onVideoChanged);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    }).catchError((Object error) {
      debugPrint('Tutorial video failed: $error');
      if (mounted) Navigator.of(context).pop(null);
    });
  }

  void _onVideoChanged() {
    if (!mounted) return;
    if (_controller.value.isPlaying && !_hasStartedPlaying) {
      _hasStartedPlaying = true;
      if (widget.guided) {

        _hintTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showCloseHint = true);
        });
      }
    }
    setState(() {});
  }

  void _togglePlay() {
    if (!_ready) return;
    final v = _controller.value;
    if (v.isPlaying) {
      _controller.pause();
    } else {
      if (v.position >= v.duration) _controller.seekTo(Duration.zero);
      _controller.play();
    }
  }

  void _close() {
    if (!_canClose) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _controller.removeListener(_onVideoChanged);
    _controller.dispose();
    super.dispose();
  }

  String get _caption {
    if (!widget.guided) return 'Tap the video to pause or play';
    if (!_hasStartedPlaying) return 'Tap the PLAY button to watch!';
    if (!_showCloseHint) return 'Watch and learn!';
    return 'When you\'re done, tap the X to continue!';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _ready && _controller.value.isPlaying;

    return PopScope(
      canPop: !widget.guided, // can't escape the guided tutorial with Back
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF806BC4), Color(0xFF51418F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD700), width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HOW TO PLAY',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio:
                      _ready ? _controller.value.aspectRatio : 16 / 9,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: _ready
                            ? GestureDetector(
                                onTap: _togglePlay,
                                child: VideoPlayer(_controller),
                              )
                            : const ColoredBox(
                                color: Colors.black,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ),
                      ),

                      if (_ready && !isPlaying)
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4081),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 52,
                              ),
                            ),
                          ),
                        ),

                      // X button (dimmed + locked in guided mode until the hint)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _canClose ? 1 : 0.35,
                          child: GestureDetector(
                            onTap: _close,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF5350),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // STEP 2: finger points at PLAY
                      if (widget.guided && _ready && !_hasStartedPlaying)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.center,
                              child: Transform.translate(
                                offset: const Offset(34, 40),
                                child: const PointingFinger(flip: false),
                              ),
                            ),
                          ),
                        ),

                      // STEP 3: finger points at X (2s after play starts)
                      if (widget.guided && _showCloseHint)
                        const Positioned(
                          top: 30,
                          right: 30,
                          child: IgnorePointer(
                            child: PointingFinger(flip: true),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PointingFinger extends StatefulWidget {
  final bool flip;
  final double size;

  const PointingFinger({super.key, required this.flip, this.size = 80});

  @override
  State<PointingFinger> createState() => _PointingFingerState();
}

class _PointingFingerState extends State<PointingFinger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_bob.value);
        final dx = (widget.flip ? 1 : -1) * 10 * t;
        final dy = -10 * t;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(widget.flip ? -1 : 1, 1, 1),
        child: Image.asset(
          'assets/images/pointing_finger.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.touch_app_rounded,
            color: Colors.white,
            size: 56,
          ),
        ),
      ),
    );
  }
}