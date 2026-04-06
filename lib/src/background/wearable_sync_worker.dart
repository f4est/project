import 'dart:io';
import 'dart:math';

import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const wearableSyncTaskName = 'fitpilot_wearable_sync';
const _historyKey = 'wearables.telemetry_history';

@pragma('vm:entry-point')
void wearableSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != wearableSyncTaskName) {
      return true;
    }
    try {
      final health = Health();
      await health.configure();
      if (Platform.isAndroid && !await health.isHealthConnectAvailable()) {
        return true;
      }

      final types = const [
        HealthDataType.STEPS,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      ];
      final end = await _networkNow();
      final start = DateTime(end.year, end.month, end.day);
      final points = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );
      final totalSteps = await health.getTotalStepsInInterval(start, end);
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
      final sleepMinutes = _sumSleepMinutes(points).round();
      final heartRate = _latestNumeric(
        points,
        HealthDataType.HEART_RATE,
      ).round();
      final spo2 = _latestNumeric(points, HealthDataType.BLOOD_OXYGEN).round();
      final prefs = await SharedPreferences.getInstance();
      final history = List<String>.from(
        prefs.getStringList(_historyKey) ?? const [],
      );
      final dayKey =
          '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
      final record =
          '$dayKey|$steps|$calories|$activeMinutes|${sleepMinutes ~/ 60}|${sleepMinutes % 60}|$heartRate|$spo2|0';
      final filtered = history
          .where((line) => !line.startsWith('$dayKey|'))
          .toList();
      filtered.add(record);
      filtered.sort();
      while (filtered.length > 60) {
        filtered.removeAt(0);
      }
      await prefs.setStringList(_historyKey, filtered);
      return true;
    } catch (_) {
      return true;
    }
  });
}

Future<DateTime> _networkNow() async {
  final endpoints = <Uri>[
    Uri.parse('https://www.google.com/generate_204'),
    Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'),
  ];
  for (final endpoint in endpoints) {
    try {
      final started = DateTime.now().toUtc();
      final response = await http
          .get(endpoint, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 6));
      final finished = DateTime.now().toUtc();
      final dateHeader = response.headers['date'];
      if (dateHeader == null || dateHeader.isEmpty) {
        continue;
      }
      final networkUtc = HttpDate.parse(dateHeader).toUtc();
      final midpoint = started.add(finished.difference(started) ~/ 2);
      final offset = networkUtc.difference(midpoint);
      return DateTime.now().toUtc().add(offset).toLocal();
    } catch (_) {}
  }
  return DateTime.now();
}

Future<void> configureWearableAutoSync({required bool enabled}) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return;
  }
  await Workmanager().initialize(wearableSyncCallbackDispatcher);
  if (!enabled) {
    await Workmanager().cancelByUniqueName(wearableSyncTaskName);
    return;
  }
  await Workmanager().registerPeriodicTask(
    wearableSyncTaskName,
    wearableSyncTaskName,
    frequency: const Duration(hours: 3),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
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
    if (!sleepTypes.contains(point.type)) continue;
    final value = point.value;
    if (value is NumericHealthValue) {
      sum += value.numericValue.toDouble();
    }
  }
  return sum;
}

double _sumNumeric(List<HealthDataPoint> points, HealthDataType type) {
  var sum = 0.0;
  for (final point in points) {
    if (point.type != type) continue;
    final value = point.value;
    if (value is NumericHealthValue) {
      sum += value.numericValue.toDouble();
    }
  }
  return sum;
}

double _latestNumeric(List<HealthDataPoint> points, HealthDataType type) {
  HealthDataPoint? latest;
  for (final point in points) {
    if (point.type != type) continue;
    if (latest == null || point.dateTo.isAfter(latest.dateTo)) {
      latest = point;
    }
  }
  if (latest == null) return 0;
  final value = latest.value;
  return value is NumericHealthValue ? value.numericValue.toDouble() : 0;
}
