import 'package:project/src/domain/entities/onboarding_profile_input.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/repositories/user_profile_repository.dart';

class SaveOnboardingProfileUseCase {
  const SaveOnboardingProfileUseCase(this._profileRepository);

  final UserProfileRepository _profileRepository;

  Future<UserProfile> call({
    required String userId,
    required String userName,
    required OnboardingProfileInput input,
  }) async {
    final profile = UserProfile(
      userId: userId,
      name: userName,
      age: input.age,
      heightCm: input.heightCm,
      weightKg: input.weightKg,
      fitnessLevel: input.fitnessLevel,
      goal: input.goal,
      lifestyleType: input.lifestyleType,
      occupation: input.occupation,
      sessionsPerWeek: input.sessionsPerWeek,
      sessionDurationMinutes: input.sessionDurationMinutes,
      availableEquipment: input.availableEquipment,
      injuryNotes: input.injuryNotes,
    );

    await _profileRepository.saveProfile(profile);
    return profile;
  }
}
