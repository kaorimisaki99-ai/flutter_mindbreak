// lib/repositories/history_repository.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/session_entry.dart';

class HistoryRepository {
  static const _boxName = 'sessions';

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SessionEntryAdapter());
    await Hive.openBox<SessionEntry>(_boxName);
  }

  Box<SessionEntry> get _box => Hive.box<SessionEntry>(_boxName);

  Future<void> addEntry(SessionEntry entry) async {
    await _box.add(entry);
  }

  List<SessionEntry> getAll() => _box.values.toList();

  List<SessionEntry> getFiltered({
    DateTime? from,
    DateTime? to,
    String? category,
  }) {
    return _box.values.where((e) {
      final afterFrom = from == null || !e.date.isBefore(from);
      final beforeTo = to == null || !e.date.isAfter(to);
      final matchCat = category == null || category == 'All' || e.category == category;
      return afterFrom && beforeTo && matchCat;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}