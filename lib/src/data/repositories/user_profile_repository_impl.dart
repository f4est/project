import 'package:project/src/data/firebase_stubs/firebase_profile_store_stub.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl(this._store);

  final UserProfileStore _store;

  @override
  Future<UserProfile?> fetchProfile(String userId) => _store.fetchProfile(userId);

  @override
  Future<void> saveProfile(UserProfile profile) => _store.saveProfile(profile);
}
