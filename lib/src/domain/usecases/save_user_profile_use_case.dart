import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/repositories/user_profile_repository.dart';

class SaveUserProfileUseCase {
  const SaveUserProfileUseCase(this._profileRepository);

  final UserProfileRepository _profileRepository;

  Future<void> call(UserProfile profile) {
    return _profileRepository.saveProfile(profile);
  }
}
