import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.voiceGender,
    required this.voiceStyle,
    required this.audioCoachEnabled,
    required this.vibrationEnabled,
    required this.fontScale,
  });

  final String voiceGender;
  final String voiceStyle;
  final bool audioCoachEnabled;
  final bool vibrationEnabled;
  final double fontScale;

  AppSettings copyWith({
    String? voiceGender,
    String? voiceStyle,
    bool? audioCoachEnabled,
    bool? vibrationEnabled,
    double? fontScale,
  }) {
    return AppSettings(
      voiceGender: voiceGender ?? this.voiceGender,
      voiceStyle: voiceStyle ?? this.voiceStyle,
      audioCoachEnabled: audioCoachEnabled ?? this.audioCoachEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  static const defaults = AppSettings(
    voiceGender: 'female',
    voiceStyle: 'warm',
    audioCoachEnabled: true,
    vibrationEnabled: true,
    fontScale: 1.0,
  );
}

class AppSettingsController extends ChangeNotifier {
  AppSettings _settings = AppSettings.defaults;
  bool _isReady = false;

  AppSettings get settings => _settings;
  bool get isReady => _isReady;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      voiceGender:
          prefs.getString(_voiceGenderKey) ?? AppSettings.defaults.voiceGender,
      voiceStyle:
          prefs.getString(_voiceStyleKey) ?? AppSettings.defaults.voiceStyle,
      audioCoachEnabled:
          prefs.getBool(_audioCoachKey) ??
          AppSettings.defaults.audioCoachEnabled,
      vibrationEnabled:
          prefs.getBool(_vibrationKey) ?? AppSettings.defaults.vibrationEnabled,
      fontScale:
          prefs.getDouble(_fontScaleKey) ?? AppSettings.defaults.fontScale,
    );
    _isReady = true;
    notifyListeners();
  }

  Future<void> update(AppSettings value) async {
    _settings = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voiceGenderKey, value.voiceGender);
    await prefs.setString(_voiceStyleKey, value.voiceStyle);
    await prefs.setBool(_audioCoachKey, value.audioCoachEnabled);
    await prefs.setBool(_vibrationKey, value.vibrationEnabled);
    await prefs.setDouble(_fontScaleKey, value.fontScale);
  }
}

const _voiceGenderKey = 'app.voice_gender';
const _voiceStyleKey = 'app.voice_style';
const _audioCoachKey = 'app.audio_coach';
const _vibrationKey = 'app.vibration_enabled';
const _fontScaleKey = 'app.font_scale';
