// lib/models/session_entry.dart
import 'package:hive/hive.dart';

part 'session_entry.g.dart';

@HiveType(typeId: 0)
class SessionEntry extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final String category; // e.g. "Focus", "Relax", "Break"

  @HiveField(2)
  final int durationMinutes;

  @HiveField(3)
  final String? note;

  SessionEntry({
    required this.date,
    required this.category,
    required this.durationMinutes,
    this.note,
  });
}