import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.voiceGender,
    required this.voiceStyle,
    required this.audioCoachEnabled,
    required this.vibrationEnabled,
    required this.fontScale,
    required this.themeMode,
    required this.autoSyncWearables,
    required this.includeSleepData,
    required this.includeStressData,
    required this.includeOxygenData,
    required this.privacyMode,
  });

  final String voiceGender;
  final String voiceStyle;
  final bool audioCoachEnabled;
  final bool vibrationEnabled;
  final double fontScale;
  final String themeMode;
  final bool autoSyncWearables;
  final bool includeSleepData;
  final bool includeStressData;
  final bool includeOxygenData;
  final bool privacyMode;

  AppSettings copyWith({
    String? voiceGender,
    String? voiceStyle,
    bool? audioCoachEnabled,
    bool? vibrationEnabled,
    double? fontScale,
    String? themeMode,
    bool? autoSyncWearables,
    bool? includeSleepData,
    bool? includeStressData,
    bool? includeOxygenData,
    bool? privacyMode,
  }) {
    return AppSettings(
      voiceGender: voiceGender ?? this.voiceGender,
      voiceStyle: voiceStyle ?? this.voiceStyle,
      audioCoachEnabled: audioCoachEnabled ?? this.audioCoachEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      fontScale: fontScale ?? this.fontScale,
      themeMode: themeMode ?? this.themeMode,
      autoSyncWearables: autoSyncWearables ?? this.autoSyncWearables,
      includeSleepData: includeSleepData ?? this.includeSleepData,
      includeStressData: includeStressData ?? this.includeStressData,
      includeOxygenData: includeOxygenData ?? this.includeOxygenData,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }

  static const defaults = AppSettings(
    voiceGender: 'female',
    voiceStyle: 'warm',
    audioCoachEnabled: true,
    vibrationEnabled: true,
    fontScale: 1.0,
    themeMode: 'system',
    autoSyncWearables: true,
    includeSleepData: true,
    includeStressData: true,
    includeOxygenData: true,
    privacyMode: false,
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
      themeMode:
          prefs.getString(_themeModeKey) ?? AppSettings.defaults.themeMode,
      autoSyncWearables:
          prefs.getBool(_autoSyncWearablesKey) ??
          AppSettings.defaults.autoSyncWearables,
      includeSleepData:
          prefs.getBool(_includeSleepDataKey) ??
          AppSettings.defaults.includeSleepData,
      includeStressData:
          prefs.getBool(_includeStressDataKey) ??
          AppSettings.defaults.includeStressData,
      includeOxygenData:
          prefs.getBool(_includeOxygenDataKey) ??
          AppSettings.defaults.includeOxygenData,
      privacyMode:
          prefs.getBool(_privacyModeKey) ?? AppSettings.defaults.privacyMode,
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
    await prefs.setString(_themeModeKey, value.themeMode);
    await prefs.setBool(_autoSyncWearablesKey, value.autoSyncWearables);
    await prefs.setBool(_includeSleepDataKey, value.includeSleepData);
    await prefs.setBool(_includeStressDataKey, value.includeStressData);
    await prefs.setBool(_includeOxygenDataKey, value.includeOxygenData);
    await prefs.setBool(_privacyModeKey, value.privacyMode);
  }
}

const _voiceGenderKey = 'app.voice_gender';
const _voiceStyleKey = 'app.voice_style';
const _audioCoachKey = 'app.audio_coach';
const _vibrationKey = 'app.vibration_enabled';
const _fontScaleKey = 'app.font_scale';
const _themeModeKey = 'app.theme_mode';
const _autoSyncWearablesKey = 'app.auto_sync_wearables';
const _includeSleepDataKey = 'app.include_sleep';
const _includeStressDataKey = 'app.include_stress';
const _includeOxygenDataKey = 'app.include_oxygen';
const _privacyModeKey = 'app.privacy_mode';
