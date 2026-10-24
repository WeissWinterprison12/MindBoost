import 'package:flutter/material.dart';

const int kAvatarCount = 8;

// Placeholders shown until your real images are added.
const List<String> kAvatarEmojis = [
  '🦊', '🐼', '🐯', '🐸', '🦉', '🐙', '🦄', '🤖',
];

String avatarAsset(int index) =>
    'assets/images/avatars/avatar_${index + 1}.png';

class PlayerAvatar extends StatelessWidget {
  final int index;
  final double size;

  const PlayerAvatar({super.key, required this.index, required this.size});

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, kAvatarCount - 1);

    return ClipOval(
      child: Image.asset(
        avatarAsset(safeIndex),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFFF1DDF4),
          alignment: Alignment.center,
          child: Text(
            kAvatarEmojis[safeIndex],
            style: TextStyle(fontSize: size * 0.55),
          ),
        ),
      ),
    );
  }
}