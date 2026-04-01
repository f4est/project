class WorkoutSessionResult {
  const WorkoutSessionResult({
    required this.date,
    required this.completed,
    required this.perceivedDifficulty,
    this.fatigueLevel = 5,
    this.enjoymentScore = 6,
    this.workoutMinutes = 30,
    this.feedback = '',
  });

  final DateTime date;
  final bool completed;
  final int perceivedDifficulty;
  final int fatigueLevel;
  final int enjoymentScore;
  final int workoutMinutes;
  final String feedback;
}
