import 'package:flutter/material.dart';
import 'package:project/src/domain/entities/onboarding_profile_input.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/presentation/controllers/session_controller.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.sessionController,
    required this.onOnboardingCollected,
  });

  final SessionController sessionController;
  final Future<void> Function(OnboardingProfileInput input)
  onOnboardingCollected;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _occupationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignInMode = false;
  TrainingGoal _selectedGoal = TrainingGoal.weightLoss;
  LifestyleType _selectedLifestyle = LifestyleType.office;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.sessionController,
      builder: (context, _) {
        final error = widget.sessionController.errorMessage;
        final isBusy = widget.sessionController.isBusy;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'FitPilot',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Персональный план домашних тренировок, контроль техники и прогресс по вашим данным.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Регистрация'),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Вход'),
                            ),
                          ],
                          selected: {_isSignInMode},
                          onSelectionChanged: isBusy
                              ? null
                              : (selection) {
                                  setState(() {
                                    _isSignInMode = selection.first;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        if (!_isSignInMode) ...[
                          TextFormField(
                            key: const Key('nameField'),
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(labelText: 'Имя'),
                            validator: (value) {
                              if (!_isSignInMode &&
                                  (value ?? '').trim().isEmpty) {
                                return 'Введите имя';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          key: const Key('emailField'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (!text.contains('@') || !text.contains('.')) {
                              return 'Некорректный email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('passwordField'),
                          controller: _passwordController,
                          textInputAction: TextInputAction.done,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Пароль',
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Минимум 6 символов';
                            }
                            return null;
                          },
                        ),
                        if (!_isSignInMode) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('ageField'),
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Возраст',
                            ),
                            validator: _validateAge,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('heightField'),
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Рост (см)',
                            ),
                            validator: _validateHeight,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('weightField'),
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Вес (кг)',
                            ),
                            validator: _validateWeight,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('occupationField'),
                            controller: _occupationController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Чем занимаетесь',
                            ),
                            validator: (value) {
                              if (!_isSignInMode &&
                                  (value ?? '').trim().length < 3) {
                                return 'Опишите род занятий';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<TrainingGoal>(
                            key: const Key('goalDropdown'),
                            initialValue: _selectedGoal,
                            isExpanded: true,
                            items: TrainingGoal.values
                                .map(
                                  (goal) => DropdownMenuItem<TrainingGoal>(
                                    value: goal,
                                    child: Text(goal.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedGoal = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Цель тренировок',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<LifestyleType>(
                            key: const Key('lifestyleDropdown'),
                            initialValue: _selectedLifestyle,
                            isExpanded: true,
                            items: LifestyleType.values
                                .map(
                                  (type) => DropdownMenuItem<LifestyleType>(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedLifestyle = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Образ жизни',
                            ),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (_isSignInMode)
                          FilledButton(
                            key: const Key('signInButton'),
                            onPressed: isBusy ? null : _handleSignIn,
                            child: isBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Войти'),
                          )
                        else
                          FilledButton(
                            key: const Key('signUpButton'),
                            onPressed: isBusy ? null : _handleSignUp,
                            child: isBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Создать аккаунт'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final success = await widget.sessionController.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _nameController.text,
    );
    if (!success) {
      return;
    }

    final user = widget.sessionController.currentUser;
    if (user == null) {
      return;
    }

    await widget.onOnboardingCollected(
      OnboardingProfileInput(
        age: int.parse(_ageController.text.trim()),
        heightCm: double.parse(
          _heightController.text.trim().replaceAll(',', '.'),
        ),
        weightKg: double.parse(
          _weightController.text.trim().replaceAll(',', '.'),
        ),
        occupation: _occupationController.text.trim(),
        goal: _selectedGoal,
        lifestyleType: _selectedLifestyle,
      ),
    );
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.sessionController.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  String? _validateAge(String? value) {
    if (_isSignInMode) {
      return null;
    }
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 14 || parsed > 80) {
      return 'Возраст 14-80';
    }
    return null;
  }

  String? _validateHeight(String? value) {
    if (_isSignInMode) {
      return null;
    }
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 130 || parsed > 230) {
      return 'Рост 130-230 см';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    if (_isSignInMode) {
      return null;
    }
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 35 || parsed > 250) {
      return 'Вес 35-250 кг';
    }
    return null;
  }
}
