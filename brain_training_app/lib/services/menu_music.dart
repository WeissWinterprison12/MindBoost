import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Add this to MaterialApp(navigatorObservers: [menuRouteObserver]) so the
/// level select screen knows when a game opens and when you come back.
final RouteObserver<PageRoute<dynamic>> menuRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// One shared background-music player for the menu screens.
///
/// Because there is only ONE player for the whole app, the music keeps
/// playing without restarting when you move from the home screen to the
/// level select screen. It is paused while a game is open and resumed
/// when you come back.
///
///   MenuMusic.instance.start();    // home screen / first tap (safe to repeat)
///   MenuMusic.instance.pause();    // a game is opening
///   MenuMusic.instance.restart();  // back on a menu screen
///
/// Every step prints a line starting with "[MenuMusic]" in the debug
/// console, so you can see exactly why the music is not playing.
class MenuMusic with WidgetsBindingObserver {
  MenuMusic._();

  static final MenuMusic instance = MenuMusic._();

  // The menu song.
  static const String asset = 'sounds/Unfolding_Patterns.mp3';

  // The volume starts at 100%. The player can change it in Options, and
  // the choice is saved on the device (0.0 = silent, 1.0 = full).
  static const double defaultVolume = 1.0;
  static const String _volumeKey = 'menu_music_volume';

  /// The current volume. Listen to this to keep a slider up to date.
  final ValueNotifier<double> volumeNotifier =
      ValueNotifier<double>(defaultVolume);

  double get volume => volumeNotifier.value;

  Future<void>? _loadingVolume;
  Timer? _saveTimer;

  // TEMPORARY SAFETY NET: if the menu song above cannot be loaded (wrong
  // file name, missing from pubspec.yaml...), this song is played instead
  // and the console explains why. Set it to '' once the menu song works.
  static const String fallbackAsset = 'sounds/Bouncing_Thoughts.mp3';

  final AudioPlayer _player = AudioPlayer();

  bool _observing = false;
  bool _starting = false;
  bool _wanted = true; // false while a game is open

  void _setup() {
    if (_observing) return;

    WidgetsBinding.instance.addObserver(this);
    _observing = true;

    debugPrint(
      '[MenuMusic] platform: '
      '${kIsWeb ? 'web' : defaultTargetPlatform.name}',
    );

    // Debug only: shows what the player is doing.
    _player.onPlayerStateChanged.listen((state) {
      debugPrint('[MenuMusic] player state: $state');
    });

    // Messages from the audio engine itself (decoding problems, etc).
    _player.onLog.listen((message) {
      debugPrint('[MenuMusic] audio engine: $message');
    });
  }

  /// Reads the saved volume (only once). Safe to call many times.
  Future<void> loadVolume() {
    return _loadingVolume ??= _readSavedVolume();
  }

  Future<void> _readSavedVolume() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final double? saved = prefs.getDouble(_volumeKey);

      if (saved != null) {
        volumeNotifier.value = saved.clamp(0.0, 1.0).toDouble();
      }

      debugPrint(
        '[MenuMusic] volume: ${(volume * 100).round()}%'
        '${saved == null ? ' (default)' : ' (saved)'}',
      );
    } catch (error) {
      debugPrint('[MenuMusic] could not read the saved volume: $error');
    }
  }

  /// Changes the volume right away and saves it for the next launch.
  Future<void> setVolume(double value) async {
    final double newVolume = value.clamp(0.0, 1.0).toDouble();

    volumeNotifier.value = newVolume;

    try {
      await _player.setVolume(newVolume);
    } catch (error) {
      debugPrint('[MenuMusic] could not change the volume: $error');
    }

    // Save shortly after the slider stops moving, not on every step.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_volumeKey, newVolume);
        debugPrint('[MenuMusic] saved volume: ${(newVolume * 100).round()}%');
      } catch (error) {
        debugPrint('[MenuMusic] could not save the volume: $error');
      }
    });
  }

  /// Starts the music. Safe to call many times: if it is already
  /// playing, nothing restarts.
  Future<void> start() async {
    _wanted = true;
    _setup();

    // Use the saved volume from the very first note.
    await loadVolume();

    if (_player.state == PlayerState.playing) return;

    if (_player.state == PlayerState.paused) {
      await _safeResume();
      return;
    }

    // Stopped, never started, or blocked by the browser: play it.
    await _playFresh();
  }

  /// Plays the menu music again from the beginning.
  ///
  /// Use this when coming back from a game. Starting the track fresh is
  /// more reliable than resuming, because a game's own audio can leave
  /// the menu player in a stopped state.
  Future<void> restart() async {
    _wanted = true;
    _setup();

    await loadVolume();

    await _playFresh(stopFirst: true);
  }

  Future<void> _playAsset(String assetPath) async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume);

    await _player.play(
      AssetSource(assetPath),
      volume: volume,
    );
  }

  Future<void> _playFresh({bool stopFirst = false}) async {
    if (_starting) return;
    _starting = true;

    try {
      if (stopFirst) {
        await _player.stop();
      }

      try {
        await _playAsset(asset);
        debugPrint('[MenuMusic] playing assets/$asset');
      } catch (error) {
        // Common causes: the file name is wrong, the file is not inside
        // assets/sounds/, it is not listed in pubspec.yaml, or a browser
        // blocked audio before the first tap.
        debugPrint('[MenuMusic] could not play assets/$asset -> $error');

        if (fallbackAsset.isNotEmpty && fallbackAsset != asset) {
          try {
            await _playAsset(fallbackAsset);
            debugPrint(
              '[MenuMusic] playing the fallback song instead: '
              'assets/$fallbackAsset',
            );
          } catch (fallbackError) {
            debugPrint(
              '[MenuMusic] the fallback song failed too -> $fallbackError',
            );
          }
        }
      }
    } finally {
      _starting = false;
    }
  }

  /// Pause while a game is open.
  Future<void> pause() async {
    _wanted = false;

    try {
      await _player.pause();
      debugPrint('[MenuMusic] paused');
    } catch (error) {
      debugPrint('[MenuMusic] could not pause: $error');
    }
  }

  /// Resume when the player is back on a menu screen.
  Future<void> resume() async {
    _wanted = true;
    await start();
  }

  Future<void> _safeResume() async {
    try {
      await _player.resume();
    } catch (error) {
      debugPrint('[MenuMusic] could not resume: $error');
    }
  }

  // Pause when the app goes to the background, resume when it returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed && _wanted) {
      start();
    }
  }
}
