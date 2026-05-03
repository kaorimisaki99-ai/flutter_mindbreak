import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tracked_app.dart';
import '../models/app_settings.dart';

const _usageChannel = MethodChannel('com.mindbreak.app/usage_stats');

class ShieldProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  List<TrackedApp> _trackedApps = [];
  bool _isLocked = false;
  String? _shieldTarget;
  bool _loadingApps = true;
  String _debugStatus = 'initializing...';

  AppSettings get settings => _settings;
  List<TrackedApp> get trackedApps => _trackedApps;
  bool get isLocked => _isLocked;
  String? get shieldTarget => _shieldTarget;
  bool get loadingApps => _loadingApps;
  String get debugStatus => _debugStatus;

  // All apps sorted by usage descending
  List<TrackedApp> get sortedApps =>
      [..._trackedApps]..sort((a, b) => b.usedMinutesToday.compareTo(a.usedMinutesToday));

  // Only non-excluded apps for tracking
  List<TrackedApp> get trackedSortedApps => sortedApps
      .where((a) => !_settings.isExcluded(a.packageId))
      .toList();

  TrackedApp? get topAppSorted =>
      trackedSortedApps.isNotEmpty ? trackedSortedApps.first : null;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  DocumentReference? get _doc => _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final settingsRaw = prefs.getString('app_settings');
    if (settingsRaw != null) {
      try {
        _settings = AppSettings.fromMap(jsonDecode(settingsRaw) as Map<String, dynamic>);
      } catch (_) {}
    }

    try {
      final snap = await _doc?.get();
      if (snap != null && snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        if (data?['settings'] != null) {
          _settings = AppSettings.fromMap(data!['settings'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    await _fetchInstalledApps();
    await _fetchRealUsage();

    _loadingApps = false;
    notifyListeners();
  }

  Future<void> _fetchInstalledApps() async {
    try {
      _debugStatus = 'fetching installed apps...';
      final result = await _usageChannel.invokeMethod<List>('getInstalledApps');

      if (result != null && result.isNotEmpty) {
        _debugStatus = 'got ${result.length} apps from device';
        _trackedApps = result.map((e) {
          final app = Map<String, String>.from(e as Map);
          return TrackedApp.fromInstalledApp(app);
        }).toList();
        notifyListeners();
        return;
      } else {
        _debugStatus = 'result empty, using defaults';
      }
    } on PlatformException catch (e) {
      _debugStatus = 'PlatformException: ${e.code}';
    } catch (e) {
      _debugStatus = 'Error: $e';
    }

    _trackedApps = TrackedApp.defaults;
    _debugStatus = 'using hardcoded defaults';
    notifyListeners();
  }

  Future<void> _fetchRealUsage() async {
    try {
      final result = await _usageChannel.invokeMethod<Map>('getUsageStats');
      if (result != null) {
        _trackedApps = _trackedApps.map((app) {
          final mins = result[app.packageId];
          if (mins != null) {
            return app.copyWith(usedMinutesToday: (mins as int));
          }
          return app;
        }).toList();
      }
    } on PlatformException {
      // permission not granted
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_settings', jsonEncode(_settings.toMap()));
    try {
      await _doc?.set({
        'settings': _settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateSettings(AppSettings updated) async {
    _settings = updated;
    notifyListeners();
    await _persist();
  }

  Future<void> toggleExclusion(String packageId) async {
    _settings = _settings.withToggleExclusion(packageId);
    notifyListeners();
    await _persist();
  }

  void triggerLock(String appName) {
    _isLocked = true;
    _shieldTarget = appName;
    notifyListeners();
  }

  void dismissShield() {
    _isLocked = false;
    _shieldTarget = null;
    notifyListeners();
  }

  void simulateUsage(String id, int minutes) {
    _trackedApps = _trackedApps.map((a) {
      if (a.id == id) return a.copyWith(usedMinutesToday: a.usedMinutesToday + minutes);
      return a;
    }).toList();
    notifyListeners();
    _persist();
  }

  void resetDailyUsage() {
    _trackedApps = _trackedApps.map((a) => a.copyWith(usedMinutesToday: 0)).toList();
    _isLocked = false;
    _shieldTarget = null;
    notifyListeners();
    _persist();
  }

  Future<void> refresh() async {
    _loadingApps = true;
    notifyListeners();
    await _fetchInstalledApps();
    await _fetchRealUsage();
    _loadingApps = false;
    notifyListeners();
  }
}