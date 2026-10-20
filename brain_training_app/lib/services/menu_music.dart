import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One shared background-music player for the menu screens.
///
/// Because there is only ONE player for the whole app, the music keeps
/// playing without restarting when you move from the home screen to the
/// level select screen. It is paused while a game is open and resumed
/// when you come back.
///
///   MenuMusic.instance.start();   // home screen / first tap (safe to repeat)
///   MenuMusic.instance.pause();   // a game is opening
///   MenuMusic.instance.resume();  // back on a menu screen
/// Add this to MaterialApp(navigatorObservers: [menuRouteObserver]) so the
/// level select screen knows when a game opens and when you come back.
final RouteObserver<PageRoute<dynamic>> menuRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class MenuMusic with WidgetsBindingObserver {
  MenuMusic._();

  static final MenuMusic instance = MenuMusic._();

  // Change these to use a different track or loudness.
  static const String asset = 'sounds/Unfolding_Patterns.mp3';
  static const double volume = 0.5; // 0.0 = silent, 1.0 = full

  final AudioPlayer _player = AudioPlayer();

  bool _observing = false;
  bool _starting = false;
  bool _started = false; // the track has begun playing
  bool _wanted = true; // false while a game is open

  /// Starts the music. Safe to call many times: if it is already
  /// playing, nothing restarts.
  Future<void> start() async {
    _wanted = true;

    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    if (_started) {
      await _safeResume();
      return;
    }

    if (_starting) return;
    _starting = true;

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);

      await _player.play(
        AssetSource(asset),
        volume: volume,
      );

      _started = true;
    } catch (error) {
      // Some browsers block audio until the first tap. Calling start()
      // again from a button press will retry.
      debugPrint('Could not start menu music: $error');
    } finally {
      _starting = false;
    }
  }

  /// Plays the menu music again from the beginning.
  ///
  /// Use this when coming back from a game. Starting the track fresh is
  /// more reliable than resuming, because a game's own audio can leave
  /// the menu player in a stopped state.
  Future<void> restart() async {
    _wanted = true;

    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);

      await _player.play(
        AssetSource(asset),
        volume: volume,
      );

      _started = true;
    } catch (error) {
      debugPrint('Could not restart menu music: $error');
    }
  }

  /// Pause while a game is open.
  Future<void> pause() async {
    _wanted = false;

    try {
      await _player.pause();
    } catch (error) {
      debugPrint('Could not pause menu music: $error');
    }
  }

  /// Resume when the player is back on a menu screen.
  Future<void> resume() async {
    _wanted = true;

    if (!_started) {
      await start();
      return;
    }

    await _safeResume();
  }

  Future<void> _safeResume() async {
    try {
      await _player.resume();
    } catch (error) {
      debugPrint('Could not resume menu music: $error');
    }
  }

  // Pause when the app goes to the background, resume when it returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed && _wanted && _started) {
      _safeResume();
    }
  }
}
