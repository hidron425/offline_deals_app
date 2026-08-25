class LevelSystem {
  static const levels = [
    {'name': 'Новичок', 'minCycles': 0},
    {'name': 'Исследователь', 'minCycles': 3},
    {'name': 'Мастер', 'minCycles': 7},
  ];

  static String getLevelName(int cycles) {
    String name = levels.first['name'] as String;
    for (final level in levels) {
      if (cycles >= (level['minCycles'] as int)) {
        name = level['name'] as String;
      }
    }
    return name;
  }

  static int getLevelIndex(int cycles) {
    int index = 0;
    for (int i = 0; i < levels.length; i++) {
      if (cycles >= (levels[i]['minCycles'] as int)) {
        index = i;
      }
    }
    return index;
  }

  static int getNextLevelCycles(int cycles) {
    for (final level in levels) {
      if (cycles < (level['minCycles'] as int)) {
        return level['minCycles'] as int;
      }
    }
    return -1; // максимальный уровень
  }
}