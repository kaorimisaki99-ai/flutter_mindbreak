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
  bool _loading = true;

  AppSettings get settings => _settings;
  List<TrackedApp> get trackedApps => _trackedApps;
  bool get isLocked => _isLocked;
  String? get shieldTarget => _shieldTarget;
  bool get loading => _loading;

  /// All installed apps (used for the exclude picker — unfiltered).
  List<TrackedApp> get allApps => [..._trackedApps];

  /// Apps sorted by usage descending; excluded apps are still shown in the
  /// home list but will never be intercepted by the blocker.
  List<TrackedApp> get sortedApps {
    final used = _trackedApps
        .where((a) => a.usedMinutesToday > 0)
        .toList()
      ..sort((a, b) => b.usedMinutesToday.compareTo(a.usedMinutesToday));
    final unused = _trackedApps
        .where((a) => a.usedMinutesToday == 0)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [...used, ...unused];
  }

  TrackedApp? get topAppSorted => sortedApps.isNotEmpty ? sortedApps.first : null;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  DocumentReference? get _doc => _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid);

  Future<void> init() async {
    _loading = true;
    notifyListeners();

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

    final appsRaw = prefs.getString('tracked_apps');
    if (appsRaw != null) {
      try {
        final list = jsonDecode(appsRaw) as List;
        _trackedApps = list
            .map((e) => TrackedApp.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    await _fetchInstalledApps();
    await _fetchRealUsage();
_loading = false;
    notifyListeners();
  }

  Future<void> _fetchInstalledApps() async {
    try {
      final result = await _usageChannel.invokeMethod<List>('getInstalledApps');
      if (result == null) return;

      final existingByPkg = {for (final a in _trackedApps) a.packageId: a};
      final merged = <TrackedApp>[];

      for (final item in result) {
        final map = Map<String, String>.from(item as Map);
        final pkg = map['packageName'] ?? '';
        final appName = map['appName'] ?? pkg;
        if (pkg.isEmpty) continue;

        if (existingByPkg.containsKey(pkg)) {
          merged.add(existingByPkg[pkg]!);
        } else {
          merged.add(TrackedApp(
            id: pkg,
            name: appName,
            packageId: pkg,
            iconAsset: 'smartphone',
            usedMinutesToday: 0,
          ));
        }
      }

      for (final existing in _trackedApps) {
        if (!merged.any((a) => a.packageId == existing.packageId)) {
          merged.add(existing);
        }
      }

      _trackedApps = merged;
    } on PlatformException {
      // Not on Android or permission issue — keep existing list
    } catch (_) {}
  }

  Future<void> _fetchRealUsage() async {
    try {
      final result = await _usageChannel.invokeMethod<Map>('getUsageStats');
      if (result == null) return;

      final byPkg = {for (final a in _trackedApps) a.packageId: a};

      for (final entry in result.entries) {
        final pkg = entry.key as String;
        final mins = (entry.value as int?) ?? 0;
        if (mins <= 0) continue;

        if (byPkg.containsKey(pkg)) {
          byPkg[pkg] = byPkg[pkg]!.copyWith(usedMinutesToday: mins);
        } else {
          byPkg[pkg] = TrackedApp(
            id: pkg,
            name: pkg.split('.').last,
            packageId: pkg,
            iconAsset: 'smartphone',
            usedMinutesToday: mins,
          );
        }
      }

      _trackedApps = byPkg.values.toList();
    } on PlatformException {
      // UsageStats permission not granted — keep values as-is
    } catch (_) {}
  }



  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_settings', jsonEncode(_settings.toMap()));
    await prefs.setString(
      'tracked_apps',
      jsonEncode(_trackedApps.map((a) => a.toMap()).toList()),
    );
    // Keep native blocker in sync every time we persist
    await _writeBlockerPrefs();
    try {
      await _doc?.set({
        'settings': _settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Calls native to write blocked_packages into mindbreak_blocker prefs.
  Future<void> _writeBlockerPrefs() async {
    try {
      final excluded = _settings.allExcludedPackages;
      final blocked = _trackedApps
          .map((a) => a.packageId)
          .where((pkg) => !excluded.contains(pkg))
          .toList();
      await _usageChannel.invokeMethod('setBlockedPackages', {'packages': blocked});
    } on PlatformException {
      // Ignore — blocker service handles missing data gracefully
    } catch (_) {}
  }

  Future<void> updateSettings(AppSettings updated) async {
    _settings = updated;
    notifyListeners();
    await _persist();
  }

  /// Toggle whether an app is excluded from blocking.
  Future<void> toggleExcluded(String packageId) async {
    final current = Set<String>.from(_settings.excludedPackages);
    if (current.contains(packageId)) {
      current.remove(packageId);
    } else {
      current.add(packageId);
    }
    await updateSettings(_settings.copyWith(excludedPackages: current));
  }

  bool isExcluded(String packageId) =>
      _settings.allExcludedPackages.contains(packageId);

  /// Re-fetches installed apps and usage stats. Called by PermissionScreen
  /// after permissions are granted.
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    await _fetchInstalledApps();
    await _fetchRealUsage();
    _loading = false;
    notifyListeners();
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
}