import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioSettings extends ChangeNotifier {
  AudioSettings._();

  static final AudioSettings instance = AudioSettings._();

  /// Default volume for new accounts: 100%.
  static const double defaultVolume = 1.0;

  double _musicVolume = defaultVolume;
  double _soundVolume = defaultVolume;

  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;

  bool _initialized = false;
  String? _loadedUid;

  StreamSubscription<User?>? _authSubscription;

  /// Initialize audio settings and watch Firebase authentication changes.
  Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    await loadForCurrentUser();

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_loadForUid(user?.uid));
    });
  }

  /// Load settings for the currently signed-in Firebase account.
  Future<void> loadForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    await _loadForUid(user?.uid);
  }

  Future<void> _loadForUid(String? uid) async {
    // Avoid unnecessary repeated loads for the same account.
    if (_loadedUid == uid) return;

    _loadedUid = uid;

    if (uid == null) {
      _musicVolume = defaultVolume;
      _soundVolume = defaultVolume;
      notifyListeners();
      return;
    }

    try {
      final document = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);

      final snapshot = await document.get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        _musicVolume = _readVolume(
          data['musicVolume'],
        );

        _soundVolume = _readVolume(
          data['soundVolume'],
        );
      } else {
        // First login: create settings with default 100% volume.
        _musicVolume = defaultVolume;
        _soundVolume = defaultVolume;

        await document.set({
          'musicVolume': defaultVolume,
          'soundVolume': defaultVolume,
        }, SetOptions(merge: true));
      }

      // Keep a local backup for convenience.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('audio_music_$uid', _musicVolume);
      await prefs.setDouble('audio_sound_$uid', _soundVolume);

      notifyListeners();
    } catch (error) {
      debugPrint('Could not load audio settings: $error');

      // Use the current account's local backup if Firestore is unavailable.
      try {
        final prefs = await SharedPreferences.getInstance();

        _musicVolume = prefs.getDouble('audio_music_$uid')
            ?? defaultVolume;

        _soundVolume = prefs.getDouble('audio_sound_$uid')
            ?? defaultVolume;

        notifyListeners();
      } catch (localError) {
        debugPrint('Could not load local audio settings: $localError');
      }
    }
  }

  double _readVolume(dynamic value) {
    if (value is num) {
      return value.toDouble().clamp(0.0, 1.0).toDouble();
    }

    return defaultVolume;
  }

  /// Change and save background music volume for this account.
  Future<void> setMusicVolume(double value) async {
    final volume = value.clamp(0.0, 1.0).toDouble();

    _musicVolume = volume;
    notifyListeners();

    await _saveVolume(
      field: 'musicVolume',
      value: volume,
    );
  }

  /// Change and save sound-effects volume for this account.
  Future<void> setSoundVolume(double value) async {
    final volume = value.clamp(0.0, 1.0).toDouble();

    _soundVolume = volume;
    notifyListeners();

    await _saveVolume(
      field: 'soundVolume',
      value: volume,
    );
  }

  Future<void> _saveVolume({
    required String field,
    required double value,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      debugPrint(
        'Audio setting changed while signed out; '
        'it will not be saved to a Firebase account.',
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final key = field == 'musicVolume'
          ? 'audio_music_$uid'
          : 'audio_sound_$uid';

      await prefs.setDouble(key, value);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        field: value,
      }, SetOptions(merge: true));

      _loadedUid = uid;
    } catch (error) {
      debugPrint('Could not save $field: $error');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}