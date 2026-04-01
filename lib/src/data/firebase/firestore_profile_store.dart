import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project/src/data/firebase_stubs/firebase_profile_store_stub.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_session.dart';

class FirestoreProfileStore implements UserProfileStore {
  FirestoreProfileStore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    final snapshot = await _users.doc(userId).get();
    if (!snapshot.exists) {
      return null;
    }
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return _profileFromMap(userId, data);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _users.doc(profile.userId).set(
      _profileToMap(profile),
      SetOptions(merge: true),
    );
  }

  @override
  Future<List<WorkoutSessionResult>> fetchRecentSessions(String userId) async {
    final query = await _users
        .doc(userId)
        .collection('sessions')
        .orderBy('date', descending: true)
        .limit(30)
        .get();

    return query.docs
        .map((doc) => _sessionFromMap(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<void> saveSession(String userId, WorkoutSessionResult result) async {
    await _users.doc(userId).collection('sessions').add(_sessionToMap(result));
  }

  Map<String, dynamic> _profileToMap(UserProfile profile) {
    return {
      'name': profile.name,
      'age': profile.age,
      'heightCm': profile.heightCm,
      'weightKg': profile.weightKg,
      'fitnessLevel': profile.fitnessLevel.name,
      'goal': profile.goal.name,
      'lifestyleType': profile.lifestyleType.name,
      'occupation': profile.occupation,
      'sessionsPerWeek': profile.sessionsPerWeek,
      'sessionDurationMinutes': profile.sessionDurationMinutes,
      'availableEquipment':
          profile.availableEquipment.map((item) => item.name).toList(),
      'injuryNotes': profile.injuryNotes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile _profileFromMap(String userId, Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim();
    final age = (map['age'] as num?)?.toInt();
    final heightCm = (map['heightCm'] as num?)?.toDouble();
    final weightKg = (map['weightKg'] as num?)?.toDouble();
    final fitnessLevelName = map['fitnessLevel'] as String?;
    final goalName = map['goal'] as String?;
    final lifestyleName = map['lifestyleType'] as String?;
    final occupation = map['occupation'] as String?;
    final sessionsPerWeek = (map['sessionsPerWeek'] as num?)?.toInt();
    final sessionDurationMinutes = (map['sessionDurationMinutes'] as num?)?.toInt();
    final injuryNotes = map['injuryNotes'] as String?;

    final equipmentRaw = map['availableEquipment'];
    final equipment = <EquipmentType>{};
    if (equipmentRaw is List) {
      for (final item in equipmentRaw) {
        if (item is String) {
          equipment.add(_equipmentFromName(item));
        }
      }
    }

    return UserProfile(
      userId: userId,
      name: (name == null || name.isEmpty) ? 'Пользователь' : name,
      age: age ?? 28,
      heightCm: heightCm ?? 172,
      weightKg: weightKg ?? 72,
      fitnessLevel: _fitnessLevelFromName(fitnessLevelName),
      goal: _goalFromName(goalName),
      lifestyleType: _lifestyleFromName(lifestyleName),
      occupation: (occupation == null || occupation.isEmpty)
          ? 'Не указано'
          : occupation,
      sessionsPerWeek: sessionsPerWeek ?? 4,
      sessionDurationMinutes: sessionDurationMinutes ?? 35,
      availableEquipment: equipment.isEmpty
          ? const {EquipmentType.bodyweight, EquipmentType.yogaMat}
          : equipment,
      injuryNotes: injuryNotes ?? '',
    );
  }

  Map<String, dynamic> _sessionToMap(WorkoutSessionResult session) {
    return {
      'date': Timestamp.fromDate(session.date),
      'completed': session.completed,
      'perceivedDifficulty': session.perceivedDifficulty,
      'fatigueLevel': session.fatigueLevel,
      'enjoymentScore': session.enjoymentScore,
      'workoutMinutes': session.workoutMinutes,
      'feedback': session.feedback,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  WorkoutSessionResult _sessionFromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is DateTime
            ? rawDate
            : DateTime.now();

    return WorkoutSessionResult(
      date: date,
      completed: (map['completed'] as bool?) ?? false,
      perceivedDifficulty: ((map['perceivedDifficulty'] as num?)?.toInt() ?? 5)
          .clamp(1, 10),
      fatigueLevel: ((map['fatigueLevel'] as num?)?.toInt() ?? 5).clamp(1, 10),
      enjoymentScore:
          ((map['enjoymentScore'] as num?)?.toInt() ?? 6).clamp(1, 10),
      workoutMinutes:
          ((map['workoutMinutes'] as num?)?.toInt() ?? 30).clamp(10, 180),
      feedback: (map['feedback'] as String?) ?? '',
    );
  }

  FitnessLevel _fitnessLevelFromName(String? value) {
    return FitnessLevel.values.firstWhere(
      (item) => item.name == value,
      orElse: () => FitnessLevel.beginner,
    );
  }

  TrainingGoal _goalFromName(String? value) {
    return TrainingGoal.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TrainingGoal.weightLoss,
    );
  }

  LifestyleType _lifestyleFromName(String? value) {
    return LifestyleType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => LifestyleType.office,
    );
  }

  EquipmentType _equipmentFromName(String value) {
    return EquipmentType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => EquipmentType.bodyweight,
    );
  }
}
