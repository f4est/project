import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WearableSource {
  const WearableSource({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.connected,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final bool connected;

  WearableSource copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? status,
    bool? connected,
  }) {
    return WearableSource(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      connected: connected ?? this.connected,
    );
  }
}

class HealthSnapshot {
  const HealthSnapshot({
    required this.calories,
    required this.steps,
    required this.activeMinutes,
    required this.idleHours,
    required this.walkingDistanceMeters,
    required this.weightKg,
    required this.sleepHours,
    required this.sleepMinutes,
    required this.heartRate,
    required this.spo2,
    required this.stress,
  });

  final int calories;
  final int steps;
  final int activeMinutes;
  final int idleHours;
  final int walkingDistanceMeters;
  final double weightKg;
  final int sleepHours;
  final int sleepMinutes;
  final int heartRate;
  final int spo2;
  final int stress;

  bool get hasAnyData =>
      calories > 0 ||
      steps > 0 ||
      activeMinutes > 0 ||
      walkingDistanceMeters > 0 ||
      weightKg > 0 ||
      heartRate > 0 ||
      sleepHours > 0 ||
      sleepMinutes > 0 ||
      spo2 > 0;
}

class TelemetryDayRecord {
  const TelemetryDayRecord({
    required this.date,
    required this.steps,
    required this.calories,
    required this.activeMinutes,
    required this.sleepHours,
    required this.sleepMinutes,
    required this.heartRate,
    required this.spo2,
    required this.stress,
  });

  final DateTime date;
  final int steps;
  final int calories;
  final int activeMinutes;
  final int sleepHours;
  final int sleepMinutes;
  final int heartRate;
  final int spo2;
  final int stress;
}

class WearablesController extends ChangeNotifier {
  WearablesController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _historyKey = 'wearables.telemetry_history';
  final Health _health = Health();
  final DateTime Function() _clock;
  bool _isSyncing = false;
  bool _isConfigured = false;
  String? _errorMessage;
  String? _actionHint;
  DateTime? _lastSyncAt;
  final Set<HealthDataType> _grantedReadTypes = <HealthDataType>{};
  final Set<String> _detectedSourceIds = <String>{};

  List<WearableSource> _sources = const [
    WearableSource(
      id: 'apple_health',
      title: 'Apple Health / Apple Watch',
      subtitle: 'Данные с iPhone и Apple Watch',
      status: 'Не подключено',
      connected: false,
    ),
    WearableSource(
      id: 'health_connect',
      title: 'Health Connect (Android)',
      subtitle: 'Основной способ подключения на Android',
      status: 'Не подключено',
      connected: false,
    ),
    WearableSource(
      id: 'google_fit',
      title: 'Google Fit',
      subtitle: 'Передача данных через Health Connect',
      status: 'Не подключено',
      connected: false,
    ),
    WearableSource(
      id: 'huawei',
      title: 'Huawei Health',
      subtitle: 'Подключение через приложение «Здоровье»',
      status: 'Не подключено',
      connected: false,
    ),
    WearableSource(
      id: 'garmin',
      title: 'Garmin Connect',
      subtitle: 'Подключение через приложение «Здоровье»',
      status: 'Не подключено',
      connected: false,
    ),
    WearableSource(
      id: 'fitbit',
      title: 'Fitbit',
      subtitle: 'Подключение через приложение «Здоровье»',
      status: 'Не подключено',
      connected: false,
    ),
    WearableSource(
      id: 'xiaomi_zepp',
      title: 'Xiaomi / Zepp Life',
      subtitle: 'Синхронизируйте Zepp с приложением «Здоровье»',
      status: 'Не подключено',
      connected: false,
    ),
  ];

  HealthSnapshot _snapshot = const HealthSnapshot(
    calories: 0,
    steps: 0,
    activeMinutes: 0,
    idleHours: 0,
    walkingDistanceMeters: 0,
    weightKg: 0,
    sleepHours: 0,
    sleepMinutes: 0,
    heartRate: 0,
    spo2: 0,
    stress: 0,
  );
  List<TelemetryDayRecord> _history = const [];

  bool get isSyncing => _isSyncing;
  List<WearableSource> get sources => _sources;
  HealthSnapshot get snapshot => _snapshot;
  List<TelemetryDayRecord> get history => _history;
  String? get errorMessage => _errorMessage;
  String? get actionHint => _actionHint;
  DateTime? get lastSyncAt => _lastSyncAt;
  List<String> get grantedTypeNames =>
      _grantedReadTypes.map((e) => e.name).toList()..sort();
  List<String> get detectedSourceIds => _detectedSourceIds.toList()..sort();
  bool get hasPrimaryConnectorConnected =>
      _sourceById('apple_health').connected ||
      _sourceById('health_connect').connected;

  Future<void> initialize() async {
    await _configureHealth();
    await _loadHistory();
    await refresh();
  }

  Future<void> connectSource(String sourceId) async {
    if (sourceId == 'apple_health' || sourceId == 'health_connect') {
      await _connectPrimarySource(sourceId);
      return;
    }

    if (!hasPrimaryConnectorConnected) {
      _setStatus(
        sourceId,
        status: 'Сначала подключите системное приложение здоровья',
        connected: false,
      );
      _errorMessage =
          'Сначала подключите Health Connect (Android) или Apple Health (iPhone).';
      _actionHint =
          'Откройте экран подключения и сначала подключите источник здоровья на телефоне.';
      notifyListeners();
      return;
    }

    _setStatus(sourceId, status: 'Идёт синхронизация', connected: false);
    _errorMessage = null;
    _actionHint = 'Подождите 10-20 секунд и нажмите обновить.';
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    _isSyncing = true;
    _errorMessage = null;
    _actionHint = null;
    notifyListeners();
    try {
      await _configureHealth();
      if (!hasPrimaryConnectorConnected) {
        _snapshot = const HealthSnapshot(
          calories: 0,
          steps: 0,
          activeMinutes: 0,
          idleHours: 0,
          walkingDistanceMeters: 0,
          weightKg: 0,
          sleepHours: 0,
          sleepMinutes: 0,
          heartRate: 0,
          spo2: 0,
          stress: 0,
        );
        _errorMessage =
            'Подключите Health Connect (Android) или Apple Health (iOS), чтобы видеть данные.';
        _actionHint =
            'Нажмите "Подключить устройство" и завершите подключение.';
        return;
      }

      final now = _clock();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final readTypes = await _resolveReadableTypes();
      if (readTypes.isEmpty) {
        _errorMessage =
            'Нет доступа к показателям. Откройте Health Connect, выберите FitPilot и включите разрешения.';
        _actionHint =
            'В Health Connect откройте FitPilot и включите доступ к шагам, пульсу, сну и калориям.';
        _snapshot = const HealthSnapshot(
          calories: 0,
          steps: 0,
          activeMinutes: 0,
          idleHours: 0,
          walkingDistanceMeters: 0,
          weightKg: 0,
          sleepHours: 0,
          sleepMinutes: 0,
          heartRate: 0,
          spo2: 0,
          stress: 0,
        );
        return;
      }
      final points = await _health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: readTypes,
      );
      _updateDetectedSources(points);

      final totalSteps = await _health.getTotalStepsInInterval(startOfDay, now);
      final steps =
          totalSteps ?? _sumNumeric(points, HealthDataType.STEPS).round();
      final calories = max(
        _sumNumeric(points, HealthDataType.TOTAL_CALORIES_BURNED).round(),
        _sumNumeric(points, HealthDataType.ACTIVE_ENERGY_BURNED).round(),
      );
      final activeMinutes = _sumNumeric(
        points,
        HealthDataType.EXERCISE_TIME,
      ).round();
      final walkingDistanceMeters = _sumNumeric(
        points,
        HealthDataType.DISTANCE_WALKING_RUNNING,
      ).round();
      final weightKg = _latestNumeric(points, HealthDataType.WEIGHT);
      final sleepMinutes = _sumSleepMinutes(points).round();
      final heartRate = _latestNumeric(
        points,
        HealthDataType.HEART_RATE,
      ).round();
      final spo2 = _latestNumeric(points, HealthDataType.BLOOD_OXYGEN).round();

      _snapshot = HealthSnapshot(
        calories: calories,
        steps: steps,
        activeMinutes: activeMinutes,
        idleHours: 0,
        walkingDistanceMeters: walkingDistanceMeters,
        weightKg: weightKg,
        sleepHours: sleepMinutes ~/ 60,
        sleepMinutes: sleepMinutes % 60,
        heartRate: heartRate,
        spo2: spo2,
        stress: 0,
      );
      _lastSyncAt = now;
      if (steps == 0 &&
          calories == 0 &&
          activeMinutes == 0 &&
          heartRate == 0 &&
          spo2 > 0) {
        _actionHint =
            'Сейчас источник передает только SpO2. Проверьте экспорт шагов, пульса и калорий в приложении браслета.';
      } else if (!_snapshot.hasAnyData) {
        _actionHint =
            'Данные пока не поступили. Выполните синхронизацию в приложении часов/браслета и обновите экран.';
      } else {
        _actionHint = null;
      }
      await _appendHistory(
        date: now,
        steps: steps,
        calories: calories,
        activeMinutes: activeMinutes,
        sleepHours: sleepMinutes ~/ 60,
        sleepMinutes: sleepMinutes % 60,
        heartRate: heartRate,
        spo2: spo2,
        stress: 0,
      );
    } catch (e) {
      _errorMessage =
          'Не удалось обновить данные. Проверьте подключение и разрешения.';
      _actionHint =
          'Проверьте интернет, перезапустите приложение часов/браслета и нажмите "Обновить".';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _connectPrimarySource(String sourceId) async {
    try {
      await _configureHealth();
      if (Platform.isAndroid && sourceId == 'health_connect') {
        final available = await _health.isHealthConnectAvailable();
        if (!available) {
          await _health.installHealthConnect();
          _setStatus(
            sourceId,
            status: 'Установите Health Connect и повторите',
            connected: false,
          );
          _errorMessage =
              'Открылся магазин Health Connect. Установите его и нажмите «Подключить» ещё раз.';
          _actionHint =
              'После установки вернитесь в FitPilot и снова нажмите "Подключить".';
          notifyListeners();
          return;
        }
      }

      final coreTypes = _coreConnectionTypes();
      var grantedCoreCount = 0;
      for (final type in coreTypes) {
        final granted = await _requestReadType(type);
        if (granted) {
          grantedCoreCount += 1;
        }
      }
      if (grantedCoreCount == 0) {
        _setStatus(sourceId, status: 'Нужны разрешения', connected: false);
        _errorMessage =
            'Нет доступа к показателям. Откройте Health Connect, выберите FitPilot и включите нужные разрешения.';
        _actionHint =
            'Включите минимум: шаги, калории, пульс, сон и кислород крови.';
        notifyListeners();
        return;
      }

      // Optional permissions request should not block the connection.
      final optionalTypes = _optionalConnectionTypes();
      final optionalPermissions = optionalTypes
          .map((_) => HealthDataAccess.READ)
          .toList();
      try {
        await _health.requestAuthorization(
          optionalTypes,
          permissions: optionalPermissions,
        );
      } catch (_) {}

      // Optional extended permissions for richer history/background sync.
      try {
        final hasHistory = await _health.isHealthDataHistoryAuthorized();
        if (!hasHistory) {
          await _health.requestHealthDataHistoryAuthorization();
        }
      } catch (_) {}

      try {
        final bgAvailable = await _health.isHealthDataInBackgroundAvailable();
        if (bgAvailable) {
          final hasBg = await _health.isHealthDataInBackgroundAuthorized();
          if (!hasBg) {
            await _health.requestHealthDataInBackgroundAuthorization();
          }
        }
      } catch (_) {}

      _setStatus(sourceId, status: 'Подключено', connected: true);
      _errorMessage = null;
      _actionHint =
          'Подключение завершено. Нажмите "Обновить", чтобы загрузить первые данные.';
      _grantedReadTypes
        ..clear()
        ..addAll(await _resolveReadableTypes());
      notifyListeners();
      await refresh();
    } catch (e) {
      _setStatus(sourceId, status: 'Ошибка подключения', connected: false);
      _errorMessage = 'Не удалось подключить устройство. Попробуйте ещё раз.';
      _actionHint =
          'Проверьте, установлено ли приложение здоровья, и повторите подключение.';
      notifyListeners();
    }
  }

  Future<void> _configureHealth() async {
    if (_isConfigured) {
      return;
    }
    await _health.configure();
    _isConfigured = true;
  }

  List<HealthDataType> _connectionTypes() {
    return [..._coreConnectionTypes(), ..._optionalConnectionTypes()];
  }

  List<HealthDataType> _coreConnectionTypes() {
    return const [
      HealthDataType.STEPS,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.HEART_RATE,
      HealthDataType.WEIGHT,
    ];
  }

  List<HealthDataType> _optionalConnectionTypes() {
    return const [
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    ];
  }

  Future<List<HealthDataType>> _resolveReadableTypes() async {
    final result = <HealthDataType>[];
    final allTypes = _connectionTypes();
    for (final type in allTypes) {
      try {
        final allowed = await _health.hasPermissions(
          [type],
          permissions: const [HealthDataAccess.READ],
        );
        if (allowed == true) {
          result.add(type);
        }
      } catch (_) {}
    }
    if (result.isNotEmpty) {
      _grantedReadTypes
        ..clear()
        ..addAll(result);
      return result;
    }
    if (_grantedReadTypes.isNotEmpty) {
      return _grantedReadTypes.toList(growable: false);
    }
    return const [];
  }

  Future<bool> _requestReadType(HealthDataType type) async {
    try {
      final already = await _health.hasPermissions(
        [type],
        permissions: const [HealthDataAccess.READ],
      );
      if (already == true) {
        return true;
      }
      return await _health.requestAuthorization(
        [type],
        permissions: const [HealthDataAccess.READ],
      );
    } catch (_) {
      return false;
    }
  }

  void _updateDetectedSources(List<HealthDataPoint> points) {
    final names = points
        .map((p) => '${p.sourceName} ${p.sourceId}'.toLowerCase())
        .join(' | ');

    bool hasAny(Iterable<String> keywords) {
      for (final keyword in keywords) {
        if (names.contains(keyword)) {
          return true;
        }
      }
      return false;
    }

    final detected = <String>{
      if (hasAny(['zepp', 'xiaomi', 'mi fitness', 'mihealth'])) 'xiaomi_zepp',
      if (hasAny(['huawei'])) 'huawei',
      if (hasAny(['garmin'])) 'garmin',
      if (hasAny(['fitbit'])) 'fitbit',
      if (hasAny(['google fit', 'com.google.android.apps.fitness']))
        'google_fit',
    };

    _detectedSourceIds
      ..clear()
      ..addAll(detected);

    _sources = _sources
        .map((source) {
          if (source.id == 'apple_health' || source.id == 'health_connect') {
            return source;
          }
          if (_detectedSourceIds.contains(source.id)) {
            return source.copyWith(connected: true, status: 'Данные поступают');
          }
          return source.copyWith(
            connected: false,
            status: 'Ожидаем первые данные',
          );
        })
        .toList(growable: false);
  }

  void _setStatus(
    String id, {
    required String status,
    required bool connected,
  }) {
    _sources = _sources
        .map(
          (s) =>
              s.id == id ? s.copyWith(status: status, connected: connected) : s,
        )
        .toList();
  }

  WearableSource _sourceById(String id) {
    return _sources.firstWhere((item) => item.id == id);
  }

  double _sumSleepMinutes(List<HealthDataPoint> points) {
    const sleepTypes = {
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    };
    var sum = 0.0;
    for (final point in points) {
      if (!sleepTypes.contains(point.type)) {
        continue;
      }
      if (point.value is NumericHealthValue) {
        sum += (point.value as NumericHealthValue).numericValue.toDouble();
      }
    }
    return sum;
  }

  double _sumNumeric(List<HealthDataPoint> points, HealthDataType type) {
    var sum = 0.0;
    for (final point in points) {
      if (point.type != type) {
        continue;
      }
      if (point.value is NumericHealthValue) {
        sum += (point.value as NumericHealthValue).numericValue.toDouble();
      }
    }
    return sum;
  }

  double _latestNumeric(List<HealthDataPoint> points, HealthDataType type) {
    HealthDataPoint? latest;
    for (final point in points) {
      if (point.type != type) {
        continue;
      }
      if (latest == null || point.dateTo.isAfter(latest.dateTo)) {
        latest = point;
      }
    }
    if (latest == null) {
      return 0;
    }
    final value = latest.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return 0;
  }

  Future<void> _appendHistory({
    required DateTime date,
    required int steps,
    required int calories,
    required int activeMinutes,
    required int sleepHours,
    required int sleepMinutes,
    required int heartRate,
    required int spo2,
    required int stress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = List<String>.from(
      prefs.getStringList(_historyKey) ?? const [],
    );
    final dayKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final line =
        '$dayKey|$steps|$calories|$activeMinutes|$sleepHours|$sleepMinutes|$heartRate|$spo2|$stress';
    final filtered = rows
        .where((value) => !value.startsWith('$dayKey|'))
        .toList();
    filtered.add(line);
    filtered.sort();
    while (filtered.length > 60) {
      filtered.removeAt(0);
    }
    await prefs.setStringList(_historyKey, filtered);
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = List<String>.from(
      prefs.getStringList(_historyKey) ?? const [],
    );
    final parsed = <TelemetryDayRecord>[];
    for (final row in rows) {
      final p = row.split('|');
      if (p.length < 9) continue;
      final date = DateTime.tryParse(p[0]);
      if (date == null) continue;
      parsed.add(
        TelemetryDayRecord(
          date: date,
          steps: int.tryParse(p[1]) ?? 0,
          calories: int.tryParse(p[2]) ?? 0,
          activeMinutes: int.tryParse(p[3]) ?? 0,
          sleepHours: int.tryParse(p[4]) ?? 0,
          sleepMinutes: int.tryParse(p[5]) ?? 0,
          heartRate: int.tryParse(p[6]) ?? 0,
          spo2: int.tryParse(p[7]) ?? 0,
          stress: int.tryParse(p[8]) ?? 0,
        ),
      );
    }
    parsed.sort((a, b) => b.date.compareTo(a.date));
    _history = parsed;
  }
}
