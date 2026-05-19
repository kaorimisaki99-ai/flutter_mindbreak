import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

class GameProvider extends ChangeNotifier {
  GameState _state = const GameState();
  List<DayUsage> _weeklyUsage = [];
  bool _loaded = false;

  GameState get state => _state;
  List<DayUsage> get weeklyUsage => _weeklyUsage;
  bool get loaded => _loaded;

  RankInfo get rankInfo => getRankInfo(_state.points);
  double get rankProgress => getRankProgress(_state.points, rankInfo);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _doc => _uid == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_uid);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('game_state');
    if (raw != null) {
      try {
        _state = GameState.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    final weeklyRaw = prefs.getString('weekly_usage');
    if (weeklyRaw != null) {
      try {
        final list = jsonDecode(weeklyRaw) as List;
        _weeklyUsage =
            list.map((e) => DayUsage.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    if (_weeklyUsage.length < 7) _generateWeeklyHistory();

    // Sync from Firestore
    try {
      final snap = await _doc?.get();
      if (snap != null && snap.exists) {
        final data = snap.data() as Map<String, dynamic>?;
        if (data != null && data['game'] != null) {
          _state = GameState.fromMap(data['game'] as Map<String, dynamic>);
          await _saveLocal(prefs);
        }
        if (data != null && data['weekly'] != null) {
          final list = data['weekly'] as List;
          _weeklyUsage =
              list.map((e) => DayUsage.fromMap(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}

    _loaded = true;
    notifyListeners();
    checkAndUpdateStreak();
  }

  void _generateWeeklyHistory() {
    final today = DateTime.now();
    _weeklyUsage = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final dateStr = '${d.year}-${d.month}-${d.day}';
      return DayUsage(date: dateStr, minutes: 0, locked: false);
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await _saveLocal(prefs);
    try {
      await _doc?.set({
        'game': _state.toMap(),
        'weekly': _weeklyUsage.map((d) => d.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _saveLocal(SharedPreferences prefs) async {
    await prefs.setString('game_state', jsonEncode(_state.toMap()));
    await prefs.setString(
      'weekly_usage',
      jsonEncode(_weeklyUsage.map((d) => d.toMap()).toList()),
    );
  }

  /// Saves a session entry to Firestore history subcollection
  Future<void> _saveSessionToHistory({
    required String category,
    required int durationMinutes,
    String note = '',
  }) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('history')
          .add({
        'date': FieldValue.serverTimestamp(),
        'category': category,
        'durationMinutes': durationMinutes,
        'note': note,
      });
    } catch (_) {}
  }

  void checkAndUpdateStreak() {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    if (_state.lastCleanDate == todayStr) return;

    final yesterday = today.subtract(const Duration(days: 1));
    final yesterStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    final newStreak = _state.lastCleanDate == yesterStr && !_state.lockedToday
        ? _state.streak + 1
        : _state.lockedToday
            ? 0
            : _state.streak;

    _state = _state.copyWith(
      streak: newStreak,
      longestStreak:
          newStreak > _state.longestStreak ? newStreak : _state.longestStreak,
      lastCleanDate: todayStr,
      lockedToday: false,
    );
    notifyListeners();
    _persist();
  }

  Future<void> markLockedToday() async {
    if (_state.lockedToday) return;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    _state = _state.copyWith(
      streak: 0,
      lockedToday: true,
      totalLockedDays: _state.totalLockedDays + 1,
    );

    _weeklyUsage = _weeklyUsage.map((d) {
      if (d.date == todayStr)
        return DayUsage(date: d.date, minutes: d.minutes, locked: true);
      return d;
    }).toList();

    notifyListeners();
    await _persist();

    // Save locked session to history
    await _saveSessionToHistory(
      category: 'Locked',
      durationMinutes: 0,
      note: 'Phone locked for today',
    );
  }

  void updateTodayUsage(int minutes) {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    bool found = false;
    _weeklyUsage = _weeklyUsage.map((d) {
      if (d.date == todayStr) {
        found = true;
        return DayUsage(date: d.date, minutes: minutes, locked: d.locked);
      }
      return d;
    }).toList();
    if (!found && _weeklyUsage.length >= 7) {
      _weeklyUsage = [
        ..._weeklyUsage.sublist(1),
        DayUsage(date: todayStr, minutes: minutes)
      ];
    }
    notifyListeners();
    _persist();

    // Save usage session to history (only when meaningful)
    if (minutes > 0) {
      _saveSessionToHistory(
        category: 'Usage',
        durationMinutes: minutes,
        note: 'Daily usage update',
      );
    }
  }
}