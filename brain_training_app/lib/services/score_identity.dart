import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/player_avatar.dart';

class PlayerIdentity {
  final String id;
  final String name;
  final int avatar;

  const PlayerIdentity({
    required this.id,
    required this.name,
    required this.avatar,
  });
}

class ScoreIdentity {
  /// Who is playing right now (signed-in account or local guest).
  static Future<PlayerIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    String id;
    String name = '';
    int avatar = prefs.getInt('player_avatar') ?? 0;

    if (user != null) {
      id = user.uid;

      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = snap.data();

        final savedName = data?['username'];
        if (savedName is String && savedName.trim().isNotEmpty) {
          name = savedName.trim();
        }

        final savedAvatar = data?['avatar'];
        if (savedAvatar is int) avatar = savedAvatar;
      } catch (e) {
        debugPrint('Could not read profile: $e');
      }

      if (name.isEmpty) {
        final display = user.displayName?.trim() ?? '';
        final email = user.email ?? '';
        name = display.isNotEmpty
            ? display
            : (email.contains('@') ? email.split('@').first : '');
      }
    } else {
      var guestId = prefs.getString('guest_player_id');

      if (guestId == null || guestId.isEmpty) {
        guestId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
        await prefs.setString('guest_player_id', guestId);
      }

      id = guestId;
    }

    if (name.isEmpty) {
      name = prefs.getString('player_username')?.trim() ?? '';
    }
    if (name.isEmpty) name = user == null ? 'Guest Player' : 'Player';

    return PlayerIdentity(
      id: id,
      name: name,
      avatar: avatar.clamp(0, kAvatarCount - 1),
    );
  }

  /// Fields every game adds to its score document.
  static Future<Map<String, dynamic>> fields() async {
    final me = await load();

    return {
      'playerId': me.id,
      'playerName': me.name,
      'avatar': me.avatar,
    };
  }
}