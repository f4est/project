class ProgressStats {
  const ProgressStats({
    required this.totalPoints,
    required this.level,
    required this.streakDays,
    required this.completedSessions,
    required this.totalSessions,
    required this.completionRatePercent,
    required this.leagueName,
    required this.localRankPosition,
    required this.coachControlMessage,
  });

  final int totalPoints;
  final int level;
  final int streakDays;
  final int completedSessions;
  final int totalSessions;
  final int completionRatePercent;
  final String leagueName;
  final int localRankPosition;
  final String coachControlMessage;
}
