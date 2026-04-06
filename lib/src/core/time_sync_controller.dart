import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TimeSyncController extends ChangeNotifier {
  Duration _networkOffset = Duration.zero;
  DateTime? _lastSyncedAt;
  String? _lastError;
  Timer? _timer;

  DateTime now() {
    final systemUtc = DateTime.now().toUtc();
    return systemUtc.add(_networkOffset).toLocal();
  }

  DateTime startOfToday() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  String get timeZoneName => DateTime.now().timeZoneName;
  Duration get timeZoneOffset => DateTime.now().timeZoneOffset;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  bool get hasNetworkSync => _lastSyncedAt != null;

  Future<void> initialize() async {
    await syncWithNetwork();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 6), (_) {
      unawaited(syncWithNetwork());
    });
  }

  Future<void> syncWithNetwork() async {
    final endpoints = <Uri>[
      Uri.parse('https://www.google.com/generate_204'),
      Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'),
      Uri.parse('https://www.microsoft.com'),
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
        _networkOffset = networkUtc.difference(midpoint);
        _lastSyncedAt = DateTime.now();
        _lastError = null;
        notifyListeners();
        return;
      } catch (_) {
        // Try next endpoint.
      }
    }

    _lastError = 'Не удалось синхронизировать время по сети.';
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
