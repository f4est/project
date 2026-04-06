import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/src/data/firebase/firebase_auth_gateway.dart';
import 'package:project/src/data/firebase/firestore_profile_store.dart';
import 'package:project/src/data/firebase_stubs/firebase_auth_stub.dart';
import 'package:project/src/data/firebase_stubs/firebase_profile_store_stub.dart';
import 'package:project/src/data/repositories/auth_repository_impl.dart';
import 'package:project/src/data/repositories/user_profile_repository_impl.dart';
import 'package:project/src/data/repositories/workout_history_repository_impl.dart';
import 'package:project/src/domain/services/progress_analyzer.dart';
import 'package:project/src/domain/services/recommendation_engine.dart';
import 'package:project/src/domain/usecases/auth/sign_in_use_case.dart';
import 'package:project/src/domain/usecases/auth/sign_out_use_case.dart';
import 'package:project/src/domain/usecases/auth/sign_up_use_case.dart';
import 'package:project/src/domain/usecases/generate_personal_plan_use_case.dart';
import 'package:project/src/domain/usecases/load_user_plan_use_case.dart';
import 'package:project/src/domain/usecases/save_onboarding_profile_use_case.dart';
import 'package:project/src/domain/usecases/save_user_profile_use_case.dart';
import 'package:project/src/presentation/controllers/plan_controller.dart';
import 'package:project/src/presentation/controllers/session_controller.dart';

class AppDependencies {
  AppDependencies._({
    required this.sessionController,
    required this.planController,
  });

  final SessionController sessionController;
  final PlanController planController;

  factory AppDependencies.create({DateTime Function()? clock}) {
    final authGateway = FirebaseAuthGateway(FirebaseAuth.instance);
    final profileStore = FirestoreProfileStore(FirebaseFirestore.instance);
    return AppDependencies._create(
      authGateway: authGateway,
      profileStore: profileStore,
      clock: clock,
    );
  }

  factory AppDependencies.createStub({DateTime Function()? clock}) {
    final authGateway = FirebaseAuthStub();
    final profileStore = FirebaseProfileStoreStub();
    return AppDependencies._create(
      authGateway: authGateway,
      profileStore: profileStore,
      clock: clock,
    );
  }

  factory AppDependencies._create({
    required AuthGateway authGateway,
    required UserProfileStore profileStore,
    DateTime Function()? clock,
  }) {
    final authRepository = AuthRepositoryImpl(authGateway);
    final profileRepository = UserProfileRepositoryImpl(profileStore);
    final historyRepository = WorkoutHistoryRepositoryImpl(profileStore);
    final recommendationEngine = RecommendationEngine();
    final progressAnalyzer = ProgressAnalyzer();

    final signInUseCase = SignInUseCase(authRepository);
    final signUpUseCase = SignUpUseCase(authRepository);
    final signOutUseCase = SignOutUseCase(authRepository);
    final generatePlanUseCase =
        GeneratePersonalPlanUseCase(recommendationEngine);
    final loadUserPlanUseCase = LoadUserPlanUseCase(
      profileRepository: profileRepository,
      workoutHistoryRepository: historyRepository,
      generatePlanUseCase: generatePlanUseCase,
      progressAnalyzer: progressAnalyzer,
    );
    final saveOnboardingProfileUseCase =
        SaveOnboardingProfileUseCase(profileRepository);
    final saveUserProfileUseCase = SaveUserProfileUseCase(profileRepository);

    final sessionController = SessionController(
      signInUseCase: signInUseCase,
      signUpUseCase: signUpUseCase,
      signOutUseCase: signOutUseCase,
      initialUser: authRepository.currentUser,
    );
    final planController = PlanController(
      loadUserPlanUseCase: loadUserPlanUseCase,
      workoutHistoryRepository: historyRepository,
      saveOnboardingProfileUseCase: saveOnboardingProfileUseCase,
      saveUserProfileUseCase: saveUserProfileUseCase,
      clock: clock,
    );

    return AppDependencies._(
      sessionController: sessionController,
      planController: planController,
    );
  }

  void dispose() {
    sessionController.dispose();
    planController.dispose();
  }
}
