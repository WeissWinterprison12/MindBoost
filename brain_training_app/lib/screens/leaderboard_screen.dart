
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const int maxLeaderboardEntries = 15;
  static const int totalQuestions = 10;

  static const Map<int, String> levelNames = {
    1: 'Math Game',
    2: 'Science Puzzle',
    3: 'Memory Match',
    4: 'Pattern Sequence',
    5: 'Tile Matrix',
    6: 'Logic Detective',
    7: 'Word Quest',
    8: 'Path Finder',
  };

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

  String playerId = 'guest-local';
  String playerName = 'Guest Player';

  bool identityLoaded = false;
  int selectedLevel = 1;

  @override
  void initState() {
    super.initState();
    loadPlayerIdentity();
  }

  // ============================================================
  // PLAYER IDENTITY
  // ============================================================

  Future<void> loadPlayerIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;

      String? guestId = prefs.getString('guest_player_id');

      if (user == null && (guestId == null || guestId.isEmpty)) {
        guestId = 'guest_${DateTime.now().microsecondsSinceEpoch}';
        await prefs.setString('guest_player_id', guestId);
      }

      final savedName = prefs.getString('player_username')?.trim();
      final displayName = user?.displayName?.trim();

      if (!mounted) return;

      setState(() {
        playerId = user?.uid ?? guestId ?? 'guest-local';

        if (savedName != null && savedName.isNotEmpty) {
          playerName = savedName;
        } else if (displayName != null && displayName.isNotEmpty) {
          playerName = displayName;
        } else {
          playerName = 'Guest Player';
        }

        identityLoaded = true;
      });
    } catch (error) {
      debugPrint('Could not load player identity: $error');

      if (mounted) {
        setState(() {
          identityLoaded = true;
        });
      }
    }
  }

  // ============================================================
  // FIRESTORE STREAM
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> scoreStream(int level) {
    return FirebaseFirestore.instance
        .collection('scores')
        .where('level', isEqualTo: level)
        .snapshots();
  }

  int asInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // SAMPLE PLAYERS
  // These are simulated demo entries, not real players.
  // ============================================================

  List<BoardEntry> makeRivals() {
    final random = Random(20261029 + selectedLevel);
    final entries = <BoardEntry>[];

    for (int i = 0; i < rivalNames.length; i++) {
      final correct = 7 + random.nextInt(4);

      final score = selectedLevel == 1
          ? correct * 100
          : 400 + random.nextInt(601);

      final xp = selectedLevel == 1
          ? correct * 10 + random.nextInt(4) * 5
          : 20 + random.nextInt(21);

      entries.add(
        BoardEntry(
          playerId: 'sample_rival_$i',
          name: rivalNames[i],
          correct: correct,
          score: score,
          accuracy: correct * 10.0,
          xp: xp,
          isYou: false,
          isSample: true,
        ),
      );
    }

    return entries;
  }

  // ============================================================
  // CONVERT A FIRESTORE DOCUMENT
  // ============================================================

  BoardEntry? entryFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final id = data['playerId']?.toString() ?? '';

    if (id.isEmpty) return null;

    final savedName = data['playerName']?.toString().trim();
    final correct = asInt(data['correct']);

    final accuracy = data['accuracy'] != null
        ? asDouble(data['accuracy'])
        : correct * 10.0;

    final score = data['score'] != null
        ? asInt(data['score'])
        : correct * 100;

    return BoardEntry(
      playerId: id,
      name: savedName != null && savedName.isNotEmpty
          ? savedName
          : (id == playerId ? playerName : 'Player'),
      correct: correct.clamp(0, totalQuestions),
      score: score,
      accuracy: accuracy,
      xp: asInt(data['xp']),
      isYou: id == playerId,
      isSample: false,
    );
  }

  // ============================================================
  // SORTING
  // Rank #1 is the highest result.
  // Level 1: correct answers > XP > accuracy.
  // Levels 2-8: score > XP.
  // ============================================================

  
  int compareEntries(BoardEntry a, BoardEntry b) {
    // Highest XP always ranks first.
    final xpComparison = b.xp.compareTo(a.xp);
    if (xpComparison != 0) return xpComparison;

    // If XP is tied, rank the higher score first.
    final scoreComparison = b.score.compareTo(a.score);
    if (scoreComparison != 0) return scoreComparison;

    // If both XP and score are tied, compare accuracy.
    final accuracyComparison = b.accuracy.compareTo(a.accuracy);
    if (accuracyComparison != 0) return accuracyComparison;

    // Final tie-breaker: alphabetical order.
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }


  // ============================================================
  // BUILD TOP 15
  // ============================================================

  List<BoardEntry> buildLeaderboard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, BoardEntry> bestByPlayer = {};

    for (final doc in docs) {
      final entry = entryFromDocument(doc);
      if (entry == null) continue;

      final previous = bestByPlayer[entry.playerId];

      if (previous == null || compareEntries(entry, previous) < 0) {
        bestByPlayer[entry.playerId] = entry;
      }
    }

    final entries = makeRivals();

    // Add each real player's best result.
    for (final entry in bestByPlayer.values) {
      entries.removeWhere(
        (sample) =>
            sample.isSample &&
            sample.name.toLowerCase() == entry.name.toLowerCase(),
      );

      entries.add(entry);
    }

    entries.sort(compareEntries);

    final topEntries = entries.take(maxLeaderboardEntries).toList();

    // Include the current player even if outside the top 15.
    // Their position is shown within this displayed list.
    final personalBest = bestByPlayer[playerId];

    if (personalBest != null &&
        !topEntries.any((entry) => entry.isYou)) {
      if (topEntries.isNotEmpty) {
        topEntries.removeLast();
      }

      topEntries.add(personalBest);
      topEntries.sort(compareEntries);
    }

    return topEntries;
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'LEADERBOARD',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF7564B8),
              Color(0xFF806BC4),
              Color(0xFF5B4A98),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: !identityLoaded
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                  ),
                )
              : Column(
                  children: [
                    // HEADER AND LEVEL SELECTOR
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MINDBOOST RANKINGS',
                            style: TextStyle(
                              color: Color(0xFFFFF176),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),

                          DropdownButtonFormField<int>(
                            value: selectedLevel,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF5B4A98),
                            decoration: InputDecoration(
                              labelText: 'Select Level',
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white30,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            items: levelNames.entries.map((entry) {
                              return DropdownMenuItem<int>(
                                value: entry.key,
                                child: Text(
                                  'LEVEL ${entry.key} • ${entry.value}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (level) {
                              if (level == null) return;

                              setState(() {
                                selectedLevel = level;
                              });
                            },
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'TOP $maxLeaderboardEntries PLAYERS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            selectedLevel == 1
                                ? ''
                                : '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // SELECTED LEVEL LEADERBOARD
                    Expanded(
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: scoreStream(selectedLevel),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return buildBoard(
                              makeRivals()
                                  .take(maxLeaderboardEntries)
                                  .toList(),
                              loadError: true,
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return buildBoard(
                              makeRivals()
                                  .take(maxLeaderboardEntries)
                                  .toList(),
                            );
                          }

                          return buildBoard(
                            buildLeaderboard(snapshot.data?.docs ?? []),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ============================================================
  // LEADERBOARD LIST
  // ============================================================

  Widget buildBoard(
    List<BoardEntry> entries, {
    bool loadError = false,
  }) {
    final hasPersonalBest = entries.any((entry) => entry.isYou);

    return Column(
      children: [
        if (!hasPersonalBest)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              'Your place: Not ranked yet. Play ${levelNames[selectedLevel]} to save your score.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        if (loadError)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Could not load saved scores. Showing sample rivals.',
              style: TextStyle(
                color: Color(0xFFFF8A65),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final rank = index + 1;
              final isYou = entry.isYou;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isYou
                      ? const Color(0xFF38EF7D).withOpacity(0.25)
                      : Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isYou
                        ? const Color(0xFF38EF7D)
                        : rank <= 3
                            ? const Color(0xFFFFD700).withOpacity(0.6)
                            : Colors.white.withOpacity(0.15),
                    width: isYou ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          color: rank <= 3
                              ? const Color(0xFFFFD700)
                              : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isYou
                          ? const Color(0xFF38EF7D)
                          : Colors.white.withOpacity(0.15),
                      child: Icon(
                        isYou ? Icons.person : Icons.sports_esports,
                        color: isYou
                            ? const Color(0xFF003816)
                            : Colors.white,
                        size: 19,
                      ),
                    ),

                    const SizedBox(width: 12),

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
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),

                          Text(
                            selectedLevel == 1
                                ? '${entry.correct}/$totalQuestions correct • ${entry.accuracy.toStringAsFixed(0)}% accuracy'
                                : 'Score: ${entry.score}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.xp} XP',
                          style: const TextStyle(
                            color: Color(0xFFFFF176),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),

                        Text(
                          isYou
                              ? 'YOUR BEST'
                              : entry.isSample
                                  ? 'SAMPLE'
                                  : 'PLAYER',
                          style: TextStyle(
                            color: isYou
                                ? const Color(0xFF38EF7D)
                                : Colors.white54,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// LEADERBOARD ENTRY MODEL
// ============================================================

class BoardEntry {
  final String playerId;
  final String name;
  final int correct;
  final int score;
  final double accuracy;
  final int xp;
  final bool isYou;
  final bool isSample;

  const BoardEntry({
    required this.playerId,
    required this.name,
    required this.correct,
    required this.score,
    required this.accuracy,
    required this.xp,
    required this.isYou,
    required this.isSample,
  });
}
