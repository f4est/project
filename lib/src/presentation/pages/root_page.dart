import 'package:flutter/material.dart';
import 'package:project/src/presentation/controllers/app_settings_controller.dart';
import 'package:project/src/presentation/controllers/plan_controller.dart';
import 'package:project/src/presentation/controllers/session_controller.dart';
import 'package:project/src/presentation/pages/auth_page.dart';
import 'package:project/src/presentation/pages/app_shell_page.dart';

class RootPage extends StatelessWidget {
  const RootPage({
    super.key,
    required this.sessionController,
    required this.planController,
    required this.settingsController,
  });

  final SessionController sessionController;
  final PlanController planController;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionController,
      builder: (context, _) {
        final user = sessionController.currentUser;
        if (user == null) {
          return AuthPage(
            sessionController: sessionController,
            onOnboardingCollected: (input) async {
              final current = sessionController.currentUser;
              if (current == null) {
                return;
              }
              await planController.saveOnboardingProfile(
                user: current,
                input: input,
              );
            },
          );
        }
        return AppShellPage(
          user: user,
          planController: planController,
          sessionController: sessionController,
          settingsController: settingsController,
        );
      },
    );
  }
}
