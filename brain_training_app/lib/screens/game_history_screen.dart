import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GameHistoryScreen extends StatelessWidget {
  final String playerId;

  const GameHistoryScreen({super.key, required this.playerId});

  DateTime? _timestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/${local.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final profile = FirebaseFirestore.instance
        .collection('users')
        .doc(playerId);

    return Scaffold(
      backgroundColor: const Color(0xFF4A0E4E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A0E4E),
        foregroundColor: Colors.white,
        title: const Text(
          'GAME HISTORY',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E4E), Color(0xFF811252), Color(0xFF2E0854)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: profile.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'History is unavailable',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)),
              );
            }

            final rawHistory = snapshot.data?.data()?['playedGameHistory'];
            final history = rawHistory is List
                ? rawHistory
                    .whereType<Map>()
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList()
                : <Map<String, dynamic>>[];

            if (history.isEmpty) {
              return const Center(
                child: Text(
                  'No recent history',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }

            final recentGames = history.reversed.take(10).toList();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: recentGames.length + 1,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'LAST ${recentGames.length} GAMES',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  );
                }

                final data = recentGames[index - 1];
                final gameName = (data['levelName'] ??
                        data['gameName'] ??
                        data['game'] ??
                        'Game')
                    .toString();
                final difficulty = (data['difficulty'] ?? '—').toString();
                final grade = (data['grade'] ?? '—').toString();
                final xp = (data['xp'] as num?)?.round() ?? 0;
                final score = data['score'];
                final accuracy = data['accuracy'];
                final completed = data['completed'] as bool?;
                final date = _formatDate(_timestamp(data['timestamp']));

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sports_esports_rounded,
                            color: Color(0xFFFFD700),
                            size: 22,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              gameName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _gradeBadge(grade),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$difficulty MODE  •  $date',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _HistoryStat(label: 'XP', value: '+$xp'),
                          if (score != null)
                            _HistoryStat(label: 'SCORE', value: '$score'),
                          if (accuracy is num)
                            _HistoryStat(
                              label: 'ACCURACY',
                              value: '${accuracy.round()}%',
                            ),
                          if (completed != null)
                            _HistoryStat(
                              label: 'RESULT',
                              value: completed ? 'COMPLETE' : 'INCOMPLETE',
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Widget _gradeBadge(String grade) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFD700).withValues(alpha: 0.14),
      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      grade.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFFFD700),
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _HistoryStat extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
