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
  AppSettings _settings = const AppSettings();
  List<TrackedApp> _trackedApps = [];
  bool _isLocked = false;
  String? _shieldTarget;
  bool _loadingApps = true;

  AppSettings get settings => _settings;
  List<TrackedApp> get trackedApps => _trackedApps;
  bool get isLocked => _isLocked;
  String? get shieldTarget => _shieldTarget;
  bool get loadingApps => _loadingApps;

  List<TrackedApp> get sortedApps =>
      [..._trackedApps]..sort((a, b) => b.usedMinutesToday.compareTo(a.usedMinutesToday));

  TrackedApp? get topAppSorted => sortedApps.isNotEmpty ? sortedApps.first : null;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  DocumentReference? get _doc => _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load settings
    final settingsRaw = prefs.getString('app_settings');
    if (settingsRaw != null) {
      try {
        _settings = AppSettings.fromMap(jsonDecode(settingsRaw) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Try Firestore settings
    try {
      final snap = await _doc?.get();
      if (snap != null && snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        if (data?['settings'] != null) {
          _settings = AppSettings.fromMap(data!['settings'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    // Load installed apps from device
    await _fetchInstalledApps(prefs);

    // Fetch real usage stats
    await _fetchRealUsage();

    _loadingApps = false;
    notifyListeners();
  }

  /// Fetches all installed apps from the device via MethodChannel
  Future<void> _fetchInstalledApps(SharedPreferences prefs) async {
    try {
      final result = await _usageChannel.invokeMethod<List>('getInstalledApps');
      if (result != null && result.isNotEmpty) {
        // Load previously saved usage data
        final savedRaw = prefs.getString('tracked_apps');
        Map<String, int> savedUsage = {};
        if (savedRaw != null) {
          try {
            final list = jsonDecode(savedRaw) as List;
            for (final e in list) {
              final map = e as Map<String, dynamic>;
              savedUsage[map['packageId'] as String] = (map['usedMinutesToday'] as int?) ?? 0;
            }
          } catch (_) {}
        }

        _trackedApps = result.map((e) {
          final app = Map<String, String>.from(e as Map);
          final tracked = TrackedApp.fromInstalledApp(app);
          return tracked.copyWith(usedMinutesToday: savedUsage[tracked.packageId] ?? 0);
        }).toList();

        return;
      }
    } on PlatformException {
      // Permission not granted yet — use defaults
    } catch (_) {}

    // Fallback to saved apps or defaults
    final appsRaw = prefs.getString('tracked_apps');
    if (appsRaw != null) {
      try {
        final list = jsonDecode(appsRaw) as List;
        _trackedApps = list.map((e) => TrackedApp.fromMap(e as Map<String, dynamic>)).toList();
        return;
      } catch (_) {}
    }
    _trackedApps = TrackedApp.defaults;
  }

  /// Calls native Kotlin to fetch real app usage via UsageStatsManager
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
      // UsageStats permission not granted
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_settings', jsonEncode(_settings.toMap()));
    await prefs.setString(
      'tracked_apps',
      jsonEncode(_trackedApps.map((a) => a.toMap()).toList()),
    );
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

  /// Refresh apps and usage — call after permission is granted
  Future<void> refresh() async {
    _loadingApps = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _fetchInstalledApps(prefs);
    await _fetchRealUsage();
    _loadingApps = false;
    notifyListeners();
  }
}