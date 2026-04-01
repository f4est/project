import 'package:project/src/domain/entities/user_profile.dart';

class OnboardingProfileInput {
  const OnboardingProfileInput({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.occupation,
    required this.goal,
    required this.lifestyleType,
    this.fitnessLevel = FitnessLevel.beginner,
    this.sessionsPerWeek = 4,
    this.sessionDurationMinutes = 35,
    this.availableEquipment = const {
      EquipmentType.bodyweight,
      EquipmentType.yogaMat,
    },
    this.injuryNotes = '',
  });

  final int age;
  final double heightCm;
  final double weightKg;
  final String occupation;
  final TrainingGoal goal;
  final LifestyleType lifestyleType;
  final FitnessLevel fitnessLevel;
  final int sessionsPerWeek;
  final int sessionDurationMinutes;
  final Set<EquipmentType> availableEquipment;
  final String injuryNotes;
}
