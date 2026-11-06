import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/score_identity.dart';
import '../widgets/player_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const int maxEntries = 15;

  static const List<String> rivalNames = [
    'PixelNinja',
    'BrainSpark',
    'NovaFox',
    'QuizKnight',
    'LunaByte',
    'QuickThinker',
    'StarPilot',
    'MathWizard',
    'BlueComet',
    'EchoPlayer',
    'TinyGenius',
    'CloudRunner',
    'LogicStorm',
    'SunnyPixel',
    'AceSolver',
  ];

  static const List<String> gameNames = [
    'Math Game',
    'Science Puzzle',
    'Memory Match',
    'Pattern Sequence',
    'Memory Matrix',
    'Logic Detective',
    'Word Quest',
    'Path Finder',
  ];

  static const Color gold = Color(0xFFFFD700);

  /// Every player's scores (needs Firestore rules that allow reading
  /// the whole `scores` collection).
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _scores;

  /// Only this player's scores. Used as a fallback when the full
  /// collection cannot be read, so your own XP still shows up.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _myScores;

  PlayerIdentity? _me;

  @override
  void initState() {
    super.initState();

    _scores = FirebaseFirestore.instance.collection('scores').snapshots();

    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await ScoreIdentity.load();
      if (!mounted) return;
      setState(() {
        _me = me;
        _myScores = FirebaseFirestore.instance
            .collection('scores')
            .where('playerId', isEqualTo: me.id)
            .snapshots();
      });
    } catch (e) {
      debugPrint('LEADERBOARD: could not load player identity: $e');
    }
  }

  // ============================================================
  // DATA
  // ============================================================

  int _asInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Simulated players so the board is never empty.
  List<BoardEntry> _makeRivals() {
    final random = Random(20261029);

    return List.generate(rivalNames.length, (i) {
      final plays = 6 + random.nextInt(19);
      var totalXp = 0;

      for (var play = 0; play < plays; play++) {
        final game = gameNames[random.nextInt(gameNames.length)];
        totalXp += _sampleXpForGame(game, random);
      }

      return BoardEntry(
        playerId: 'sample_$i',
        name: rivalNames[i],
        avatar: i % kAvatarCount,
        totalXp: totalXp,
        plays: plays,
        isYou: false,
        isSample: true,
      );
    });
  }

  int _sampleXpForGame(String game, Random random) {
    final (minimum, maximum) = switch (game) {
      'Math Game' => (100, 180),
      'Science Puzzle' => (40, 100),
      'Memory Match' => (25, 75),
      'Pattern Sequence' => (30, 90),
      'Memory Matrix' => (30, 80),
      'Logic Detective' => (20, 50),
      'Word Quest' => (40, 140),
      'Path Finder' => (60, 180),
      _ => (20, 60),
    };
    return minimum + random.nextInt(maximum - minimum + 1);
  }

  int _compare(BoardEntry a, BoardEntry b) {
    final byXp = b.totalXp.compareTo(a.totalXp);
    if (byXp != 0) return byXp;

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Adds up every score a player has saved, across all 8 games.
  List<BoardEntry> _buildRanking(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final totals = <String, _Totals>{};
    int skipped = 0;

    for (final doc in docs) {
      final data = doc.data();
      final id = data['playerId']?.toString() ?? '';

      if (id.isEmpty) {
        skipped++; // older scores without a player
        continue;
      }

      final t = totals.putIfAbsent(id, () => _Totals());

      t.xp += _asInt(data['xp']);
      t.plays++;

      final name = data['playerName']?.toString().trim() ?? '';
      if (name.isNotEmpty) t.name = name;

      final avatar = data['avatar'];
      if (avatar is int) t.avatar = avatar;
    }

    debugPrint(
      'LEADERBOARD: ${docs.length} scores loaded, $skipped without '
      'playerId, ${totals.length} players, my id = ${_me?.id}',
    );

    final entries = _makeRivals();

    totals.forEach((id, t) {
      final isYou = id == _me?.id;

      final name = isYou ? _me!.name : (t.name.isEmpty ? 'Player' : t.name);

      entries.removeWhere(
        (e) => e.isSample && e.name.toLowerCase() == name.toLowerCase(),
      );

      entries.add(
        BoardEntry(
          playerId: id,
          name: name,
          avatar: (isYou ? _me!.avatar : t.avatar)
              .clamp(0, kAvatarCount - 1),
          totalXp: t.xp,
          plays: t.plays,
          isYou: isYou,
          isSample: false,
        ),
      );
    });

    entries.sort(_compare);

    return entries;
  }

  String _format(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }

    return buffer.toString();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A0E4E),
              Color(0xFF811252),
              Color(0xFF2E0854),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _scores,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // The reason is printed in the console: look for
                // "LEADERBOARD error". "permission-denied" means the
                // Firestore rules do not allow reading all scores.
                debugPrint('LEADERBOARD error: ${snapshot.error}');
                return _buildFallback(snapshot.error);
              }

              final List<BoardEntry> ranking = snapshot.data == null
                  ? (_makeRivals()..sort(_compare))
                  : _buildRanking(snapshot.data!.docs);

              return _buildContent(ranking);
            },
          ),
        ),
      ),
    );
  }

  /// Used when the full scores collection cannot be read.
  /// Shows sample players plus the player's own saved scores.
  Widget _buildFallback(Object? error) {
    final bool denied = error.toString().contains('permission-denied');

    final String notice = denied
        ? 'Live ranking is blocked by Firestore rules. '
            'Showing your own scores with sample players.'
        : 'Could not load all scores. '
            'Showing your own scores with sample players.';

    final mine = _myScores;

    if (mine == null) {
      return _buildContent(
        _makeRivals()..sort(_compare),
        notice: notice,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: mine,
      builder: (context, mySnapshot) {
        if (mySnapshot.hasError) {
          debugPrint('LEADERBOARD own-scores error: ${mySnapshot.error}');
        }

        final List<BoardEntry> ranking = mySnapshot.data == null
            ? (_makeRivals()..sort(_compare))
            : _buildRanking(mySnapshot.data!.docs);

        return _buildContent(ranking, notice: notice);
      },
    );
  }

  Widget _buildContent(
    List<BoardEntry> ranking, {
    String? notice,
  }) {
    final int myIndex = ranking.indexWhere((e) => e.isYou);
    final List<BoardEntry> top = ranking.take(maxEntries).toList();

    // If the player is outside the top list, their row is pinned
    // under the list so they can always see their real rank.
    final bool pinMe = myIndex >= maxEntries;

    return Column(
      children: [
        _buildHeader(),
        _buildTitle(),
        const SizedBox(height: 14),
        _buildMyRankCard(
          myIndex >= 0 ? ranking[myIndex] : null,
          myIndex >= 0 ? myIndex + 1 : null,
        ),
        const SizedBox(height: 14),
        _buildSectionLabel(),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
            child: Text(
              notice,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFF8A65),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    physics: const BouncingScrollPhysics(),
                    itemCount: top.length,
                    itemBuilder: (context, index) {
                      return _buildRow(top[index], index + 1);
                    },
                  ),
                ),
                if (pinMe) ...[
                  const Divider(color: Colors.white24, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
                    child: _buildRow(ranking[myIndex], myIndex + 1),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 14, 40, 16),
          child: _ThreeDButton(
            text: 'BACK',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: gold, width: 2),
          ),
          child: const Text(
            'LEADERBOARD',
            style: TextStyle(
              color: gold,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFF176), Color(0xFFFF8A65)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: const Text(
            '🏆 TOP PLAYERS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(2, 4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
        const Text(
          'Total XP earned across all 8 games',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // MY RANK CARD
  // ------------------------------------------------------------

  Widget _buildMyRankCard(BoardEntry? entry, int? rank) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0B46), Color(0xFF5B1A6B)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.2),
            blurRadius: 16,
          ),
          const BoxShadow(
            color: Colors.black38,
            offset: Offset(0, 5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(entry?.avatar ?? _me?.avatar ?? 0, 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR RANK',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  entry?.name ?? _me?.name ?? 'Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  entry == null
                      ? 'Play a game to earn XP and get ranked!'
                      : '${entry.plays} games played',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rank == null ? '—' : '#$rank',
                style: const TextStyle(
                  color: gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _xpPill(entry?.totalXp ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'TOP $maxEntries PLAYERS',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Colors.white24)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // LIST ROW
  // ------------------------------------------------------------

  Widget _buildRow(BoardEntry entry, int rank) {
    final Color? medal = switch (rank) {
      1 => gold,
      2 => const Color(0xFFC9D1E3),
      3 => const Color(0xFFCD7F32),
      _ => null,
    };

    final bool isYou = entry.isYou;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isYou
            ? const Color(0xFF38EF7D).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isYou
              ? const Color(0xFF38EF7D)
              : (medal?.withValues(alpha: 0.8) ?? Colors.white12),
          width: isYou || medal != null ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal ?? Colors.black.withValues(alpha: 0.35),
              boxShadow: medal == null
                  ? null
                  : [
                      BoxShadow(
                        color: medal.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: medal == null
                    ? Colors.white70
                    : const Color(0xFF3B0B46),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _avatar(entry.avatar, 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYou ? '${entry.name} (You)' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${entry.plays} games played',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _xpPill(entry.totalXp),
        ],
      ),
    );
  }

  Widget _avatar(int index, double size) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: gold, width: 2),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white,
        child: PlayerAvatar(index: index, size: size),
      ),
    );
  }

  Widget _xpPill(int xp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: gold, size: 18),
          const SizedBox(width: 4),
          Text(
            '${_format(xp)} XP',
            style: const TextStyle(
              color: Color(0xFFFFF176),
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

class _Totals {
  int xp = 0;
  int plays = 0;
  String name = '';
  int avatar = 0;
}

class BoardEntry {
  final String playerId;
  final String name;
  final int avatar;
  final int totalXp;
  final int plays;
  final bool isYou;
  final bool isSample;

  const BoardEntry({
    required this.playerId,
    required this.name,
    required this.avatar,
    required this.totalXp,
    required this.plays,
    required this.isYou,
    required this.isSample,
  });
}

class _ThreeDButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const _ThreeDButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_ThreeDButton> createState() => _ThreeDButtonState();
}

class _ThreeDButtonState extends State<_ThreeDButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 54,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4081),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF990033),
              offset: Offset(0, _pressed ? 1 : 5),
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
            Icon(widget.icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              widget.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
