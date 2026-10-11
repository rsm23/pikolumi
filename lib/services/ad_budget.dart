class AdBudget {
  int foregroundMs, completions;
  int? lastAdForegroundMs;
  List<int> shownAt;
  AdBudget({
    this.foregroundMs = 0,
    this.completions = 0,
    this.lastAdForegroundMs,
    List<int>? shownAt,
  }) : shownAt = shownAt ?? [];
  factory AdBudget.fromJson(Map<String, dynamic> j) => AdBudget(
    foregroundMs: j['foregroundMs'] ?? 0,
    completions: j['completions'] ?? 0,
    lastAdForegroundMs: j['lastAdForegroundMs'],
    shownAt: (j['shownAt'] as List? ?? []).cast<int>(),
  );
  Map<String, dynamic> toJson() => {
    'foregroundMs': foregroundMs,
    'completions': completions,
    'lastAdForegroundMs': lastAdForegroundMs,
    'shownAt': shownAt,
  };
  void addForeground(Duration elapsed) {
    foregroundMs += elapsed.inMilliseconds;
  }

  void completed() {
    completions++;
  }

  bool eligible(DateTime now) {
    final millis = now.millisecondsSinceEpoch;
    shownAt.removeWhere((t) => millis - t >= 3600000);
    return foregroundMs >= 300000 &&
        completions >= 4 &&
        (lastAdForegroundMs == null ||
            foregroundMs - lastAdForegroundMs! >= 300000) &&
        shownAt.length < 6;
  }

  void shown(DateTime now) {
    lastAdForegroundMs = foregroundMs;
    completions = 0;
    shownAt.add(now.millisecondsSinceEpoch);
  }
}
