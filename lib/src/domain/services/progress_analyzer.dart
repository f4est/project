import 'dart:math';

import 'package:project/src/domain/entities/progress_stats.dart';
import 'package:project/src/domain/entities/workout_session.dart';

class ProgressAnalyzer {
  ProgressStats analyze(List<WorkoutSessionResult> sessions) {
    if (sessions.isEmpty) {
      return const ProgressStats(
        totalPoints: 0,
        level: 1,
        streakDays: 0,
        completedSessions: 0,
        totalSessions: 0,
        completionRatePercent: 0,
        leagueName: 'Новичок',
        localRankPosition: 1200,
        coachControlMessage: 'Начните первую тренировку, чтобы получить контроль прогресса.',
      );
    }

    final ordered = List<WorkoutSessionResult>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final completed = ordered.where((session) => session.completed).toList();
    final completedCount = completed.length;
    final completionRate = ((completedCount / ordered.length) * 100).round();

    var points = 0;
    for (final session in ordered) {
      if (!session.completed) {
        points += 2;
        continue;
      }
      final base = 40 + (session.enjoymentScore * 2) - session.fatigueLevel;
      points += max(10, base) + (session.workoutMinutes ~/ 8);
    }

    final level = 1 + (points ~/ 320);
    final streak = _calculateStreak(ordered);
    final league = _leagueByPoints(points);
    final localRankPosition = max(1, 1200 - points);
    final coachControlMessage = _coachControlMessage(
      completionRatePercent: completionRate,
      streakDays: streak,
      recentFatigue: _recentAverageFatigue(ordered),
    );

    return ProgressStats(
      totalPoints: points,
      level: level,
      streakDays: streak,
      completedSessions: completedCount,
      totalSessions: ordered.length,
      completionRatePercent: completionRate,
      leagueName: league,
      localRankPosition: localRankPosition,
      coachControlMessage: coachControlMessage,
    );
  }

  int _calculateStreak(List<WorkoutSessionResult> ordered) {
    var streak = 0;
    DateTime? previous;
    for (final session in ordered) {
      if (!session.completed) {
        break;
      }
      if (previous == null) {
        streak = 1;
        previous = session.date;
        continue;
      }
      final gap = previous.difference(session.date).inDays.abs();
      if (gap <= 1) {
        streak += 1;
        previous = session.date;
      } else {
        break;
      }
    }
    return streak;
  }

  String _leagueByPoints(int points) {
    if (points >= 2400) {
      return 'Легенда';
    }
    if (points >= 1400) {
      return 'Профи';
    }
    if (points >= 700) {
      return 'Продвинутый';
    }
    if (points >= 300) {
      return 'Любитель';
    }
    return 'Новичок';
  }

  double _recentAverageFatigue(List<WorkoutSessionResult> ordered) {
    final recent = ordered.take(5).where((session) => session.completed).toList();
    if (recent.isEmpty) {
      return 0;
    }
    final sum = recent
        .map((session) => session.fatigueLevel)
        .reduce((a, b) => a + b);
    return sum / recent.length;
  }

  String _coachControlMessage({
    required int completionRatePercent,
    required int streakDays,
    required double recentFatigue,
  }) {
    if (completionRatePercent < 55) {
      return 'Контроль: высокий риск пропусков. Упростите план и фиксируйте каждую сессию.';
    }
    if (recentFatigue >= 8) {
      return 'Контроль: признаков переутомления много. Нужен облегчённый микроцикл.';
    }
    if (streakDays >= 5) {
      return 'Контроль: отличная дисциплина. Можно аккуратно повысить нагрузку.';
    }
    return 'Контроль: стабильный темп. Продолжайте регулярные отчёты после тренировки.';
  }
}
