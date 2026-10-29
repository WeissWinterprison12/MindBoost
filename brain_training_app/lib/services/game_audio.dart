import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_settings.dart';

/// One audio controller shared by every game (music, effects, ducking, mute).
///
/// Each game can pass its own background music:
///   final GameAudio audio = GameAudio(musicAsset: 'sounds/My_Song.mp3');
class GameAudio extends ChangeNotifier {
  GameAudio({this.musicAsset = 'sounds/Bouncing_Thoughts.mp3'});

  static const double _duckLevel = 0.3;

  /// The background music file for this game (relative to assets/).
  final String musicAsset;

  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _correct = AudioPlayer();
  final AudioPlayer _wrong = AudioPlayer();
  final AudioPlayer _complete = AudioPlayer();
  final AudioPlayer _extra = AudioPlayer(); // pop, click, etc.

  late final List<AudioPlayer> _effects = [
    _correct,
    _wrong,
    _complete,
    _extra,
  ];

  double musicVolume = AudioSettings.defaultVolume;
  double soundVolume = AudioSettings.defaultVolume;

  // Remembered so un-muting restores the previous level.
  double _lastMusicVolume = 1.0;
  double _lastSoundVolume = 1.0;

  bool _effectsReady = false;
  bool _musicActive = false; // game is running (not paused / finished)
  bool _musicStoppedForMute = false;
  bool _disposed = false;
  int _duckToken = 0;

  bool get musicMuted => musicVolume <= 0.0;
  bool get soundMuted => soundVolume <= 0.0;
  bool get allMuted => musicMuted && soundMuted;

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------

  Future<void> init() async {
    final settings = AudioSettings.instance;

    await settings.initialize();
    await settings.loadForCurrentUser();

    if (_disposed) return;

    musicVolume = settings.musicVolume;
    soundVolume = settings.soundVolume;
    if (musicVolume > 0) _lastMusicVolume = musicVolume;
    if (soundVolume > 0) _lastSoundVolume = soundVolume;
    _notify();

    await _configure();
    await _loadEffects();
  }

  Future<void> _configure() async {
    final context = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    );

    try {
      await _music.setAudioContext(context);
      for (final p in _effects) {
        await p.setAudioContext(context);
      }
    } catch (e) {
      debugPrint('Could not set audio mixing: $e');
    }
  }

  Future<void> _loadEffects() async {
    try {
      for (final p in _effects) {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(soundVolume);
      }

      await _correct.setSource(AssetSource('sounds/correct.mp3'));
      await _wrong.setSource(AssetSource('sounds/wrong.mp3'));
      await _complete.setSource(AssetSource('sounds/level up.mp3'));

      _effectsReady = true;
    } catch (e) {
      debugPrint('Could not preload sound effects: $e');
    }
  }

  // ------------------------------------------------------------
  // MUSIC
  // ------------------------------------------------------------

  Future<void> startMusic() async {
    _musicActive = true;

    if (musicVolume <= 0.0) {
      _musicStoppedForMute = true;
      try {
        await _music.stop();
      } catch (_) {}
      return;
    }

    try {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(musicVolume);
      await _music.play(AssetSource(musicAsset), volume: musicVolume);
      _musicStoppedForMute = false;
    } catch (e) {
      debugPrint('Could not play background music: $e');
    }
  }

  Future<void> stopMusic() async {
    _musicActive = false;
    _duckToken++;
    try {
      await _music.stop();
    } catch (_) {}
  }

  void pauseAll() {
    _musicActive = false;
    _duckToken++;

    for (final p in _effects) {
      p.pause();
    }
    _music.pause();
  }

  Future<void> resume() async {
    _musicActive = true;

    try {
      if (musicVolume <= 0.0) {
        await _music.stop();
        _musicStoppedForMute = true;
      } else if (_musicStoppedForMute) {
        await startMusic();
      } else {
        await _music.setVolume(musicVolume);
        await _music.resume();
      }
    } catch (e) {
      debugPrint('Could not resume music: $e');
    }

    try {
      for (final p in _effects) {
        await p.setVolume(soundVolume);
      }
    } catch (_) {}
  }

  void stopEffects() {
    for (final p in _effects) {
      p.stop();
    }
  }

  // ------------------------------------------------------------
  // VOLUME + MUTE
  // ------------------------------------------------------------

  Future<void> setMusicVolume(double value) async {
    final double v = value.clamp(0.0, 1.0).toDouble();

    musicVolume = v;
    if (v > 0) _lastMusicVolume = v;
    _notify();

    await AudioSettings.instance.setMusicVolume(v);

    try {
      if (v <= 0.0) {
        _musicStoppedForMute = true;
        await _music.stop();
        return;
      }

      if (_musicStoppedForMute) {
        // Only restart if the game is actually running; otherwise
        // resume() will start it later.
        if (_musicActive) await startMusic();
        return;
      }

      await _music.setVolume(v);
    } catch (e) {
      debugPrint('Could not change music volume: $e');
    }
  }

  Future<void> setSoundVolume(double value) async {
    final double v = value.clamp(0.0, 1.0).toDouble();

    soundVolume = v;
    if (v > 0) _lastSoundVolume = v;
    _notify();

    await AudioSettings.instance.setSoundVolume(v);

    try {
      for (final p in _effects) {
        await p.setVolume(v);
      }
    } catch (e) {
      debugPrint('Could not change sound volume: $e');
    }
  }

  /// Tapping the music icon: mute (0%) or restore the previous level.
  Future<void> toggleMusicMute() =>
      setMusicVolume(musicMuted ? _lastMusicVolume : 0.0);

  /// Tapping the sound-effects icon.
  Future<void> toggleSoundMute() =>
      setSoundVolume(soundMuted ? _lastSoundVolume : 0.0);

  /// "Mute all sounds" button.
  Future<void> toggleMuteAll() async {
    if (allMuted) {
      await setMusicVolume(_lastMusicVolume);
      await setSoundVolume(_lastSoundVolume);
    } else {
      await setMusicVolume(0.0);
      await setSoundVolume(0.0);
    }
  }

  // ------------------------------------------------------------
  // EFFECTS
  // ------------------------------------------------------------

  void playCorrect() => _playEffect(_correct, 'correct.mp3');
  void playWrong() => _playEffect(_wrong, 'wrong.mp3');
  void playComplete() => _playEffect(_complete, 'level up.mp3');

  /// Any other short effect from assets/sounds (for example 'pop.mp3').
  /// It does not lower the music volume.
  Future<void> playSfx(String fileName) async {
    if (_disposed || soundVolume <= 0.0) return;

    try {
      await _extra.stop();
      await _extra.play(
        AssetSource('sounds/$fileName'),
        volume: soundVolume,
      );
    } catch (e) {
      debugPrint('Could not play $fileName: $e');
    }
  }

  Future<void> _duckMusic(AudioPlayer effectPlayer) async {
    if (musicMuted || _musicStoppedForMute || !_musicActive) return;

    final int token = ++_duckToken;
    final Future<void> finished = effectPlayer.onPlayerComplete.first;

    try {
      await _music.setVolume(musicVolume * _duckLevel);
    } catch (_) {}

    try {
      await Future.any<void>([
        finished,
        Future<void>.delayed(const Duration(seconds: 3)),
      ]);
    } catch (_) {}

    if (_disposed || token != _duckToken) return;

    try {
      await _music.setVolume(musicVolume);
    } catch (_) {}
  }

  Future<void> _playEffect(AudioPlayer player, String file) async {
    if (_disposed || soundVolume <= 0.0) return;

    _duckMusic(player);

    try {
      if (_effectsReady) {
        await player.stop();
        await player.resume();
      } else {
        await player.play(AssetSource('sounds/$file'), volume: soundVolume);
      }
    } catch (e) {
      try {
        await player.play(AssetSource('sounds/$file'), volume: soundVolume);
      } catch (retryError) {
        debugPrint('Could not play $file: $retryError');
      }
    }
  }

  // ------------------------------------------------------------

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _duckToken++;

    for (final p in _effects) {
      p.dispose();
    }
    _music.dispose();

    super.dispose();
  }
}