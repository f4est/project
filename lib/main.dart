import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:project/src/app/home_workout_ai_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HomeWorkoutAiApp());
}
