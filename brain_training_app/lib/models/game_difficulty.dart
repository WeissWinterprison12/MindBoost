
enum GameDifficulty {
  easy,
  medium,
  hard,
}

extension GameDifficultyInfo on GameDifficulty {
  String get label {
    switch (this) {
      case GameDifficulty.easy:
        return 'EASY';
      case GameDifficulty.medium:
        return 'MEDIUM';
      case GameDifficulty.hard:
        return 'HARD';
    }
  }

  int get timeLimit {
    switch (this) {
      case GameDifficulty.easy:
        return 0;
      case GameDifficulty.medium:
        return 20;
      case GameDifficulty.hard:
        return 10;
    }
  }
}
