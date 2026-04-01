enum FitnessLevel { beginner, intermediate, advanced }

extension FitnessLevelX on FitnessLevel {
  String get label => switch (this) {
        FitnessLevel.beginner => 'Начальный',
        FitnessLevel.intermediate => 'Средний',
        FitnessLevel.advanced => 'Продвинутый',
      };
}

enum TrainingGoal { weightLoss, muscleGain, endurance, mobility }

extension TrainingGoalX on TrainingGoal {
  String get label => switch (this) {
        TrainingGoal.weightLoss => 'Снижение веса',
        TrainingGoal.muscleGain => 'Рост мышц',
        TrainingGoal.endurance => 'Выносливость',
        TrainingGoal.mobility => 'Мобильность',
      };
}

enum LifestyleType { office, student, activeWork, athlete }

extension LifestyleTypeX on LifestyleType {
  String get label => switch (this) {
        LifestyleType.office => 'Офис',
        LifestyleType.student => 'Учёба',
        LifestyleType.activeWork => 'Активная работа',
        LifestyleType.athlete => 'Спортсмен',
      };
}

enum EquipmentType {
  bodyweight,
  dumbbells,
  resistanceBands,
  kettlebell,
  yogaMat,
}

extension EquipmentTypeX on EquipmentType {
  String get label => switch (this) {
        EquipmentType.bodyweight => 'Собственный вес',
        EquipmentType.dumbbells => 'Гантели',
        EquipmentType.resistanceBands => 'Резинки',
        EquipmentType.kettlebell => 'Гиря',
        EquipmentType.yogaMat => 'Коврик',
      };
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.fitnessLevel,
    required this.goal,
    required this.lifestyleType,
    required this.occupation,
    required this.sessionsPerWeek,
    required this.sessionDurationMinutes,
    required this.availableEquipment,
    required this.injuryNotes,
  });

  final String userId;
  final String name;
  final int age;
  final double heightCm;
  final double weightKg;
  final FitnessLevel fitnessLevel;
  final TrainingGoal goal;
  final LifestyleType lifestyleType;
  final String occupation;
  final int sessionsPerWeek;
  final int sessionDurationMinutes;
  final Set<EquipmentType> availableEquipment;
  final String injuryNotes;

  factory UserProfile.defaultProfile({
    required String userId,
    required String name,
  }) {
    return UserProfile(
      userId: userId,
      name: name,
      age: 28,
      heightCm: 172,
      weightKg: 72,
      fitnessLevel: FitnessLevel.beginner,
      goal: TrainingGoal.weightLoss,
      lifestyleType: LifestyleType.office,
      occupation: 'Не указано',
      sessionsPerWeek: 4,
      sessionDurationMinutes: 35,
      availableEquipment: const {
        EquipmentType.bodyweight,
        EquipmentType.yogaMat,
      },
      injuryNotes: '',
    );
  }

  UserProfile copyWith({
    String? userId,
    String? name,
    int? age,
    double? heightCm,
    double? weightKg,
    FitnessLevel? fitnessLevel,
    TrainingGoal? goal,
    LifestyleType? lifestyleType,
    String? occupation,
    int? sessionsPerWeek,
    int? sessionDurationMinutes,
    Set<EquipmentType>? availableEquipment,
    String? injuryNotes,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      goal: goal ?? this.goal,
      lifestyleType: lifestyleType ?? this.lifestyleType,
      occupation: occupation ?? this.occupation,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      injuryNotes: injuryNotes ?? this.injuryNotes,
    );
  }
}
