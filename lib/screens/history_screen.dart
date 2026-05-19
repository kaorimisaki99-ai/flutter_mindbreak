import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedCategory = 'All';
  DateTimeRange? _dateRange;

  final _categories = ['All', 'Locked', 'Usage'];

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Query get _baseQuery => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('history')
      .orderBy('date', descending: true);

  List<Map<String, dynamic>> _applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs
        .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
        .where((e) {
      final date = (e['date'] as Timestamp?)?.toDate();
      final matchCat =
          _selectedCategory == 'All' || e['category'] == _selectedCategory;
      final matchFrom = _dateRange == null ||
          date == null ||
          !date.isBefore(_dateRange!.start);
      final matchTo = _dateRange == null ||
          date == null ||
          !date.isAfter(
              _dateRange!.end.add(const Duration(hours: 23, minutes: 59)));
      return matchCat && matchFrom && matchTo;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.primaryFg,
            surface: AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) setState(() => _dateRange = range);
  }

  void _clearFilters() => setState(() {
        _selectedCategory = 'All';
        _dateRange = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text(
          'History',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedCategory != 'All' || _dateRange != null)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear',
                  style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _baseQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final allDocs = snapshot.data?.docs ?? [];
          final entries = _applyFilters(allDocs);

          return Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: entries.isEmpty
                    ? _buildEmpty()
                    : ListView(
                        children: [
                          _buildAnalyticsSummary(entries),
                          _buildSectionHeader('Sessions'),
                          ..._buildList(entries),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontSize: 13,
                      ),
                      backgroundColor: AppColors.background,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _dateRange != null
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.background,
                border: Border.all(
                  color: _dateRange != null
                      ? AppColors.primary
                      : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    size: 14,
                    color: _dateRange != null
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _dateRange != null
                        ? '${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d').format(_dateRange!.end)}'
                        : 'Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: _dateRange != null
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSummary(List<Map<String, dynamic>> entries) {
    final totalMinutes = entries.fold<int>(
        0, (total, e) => total + ((e['durationMinutes'] ?? 0) as int));
    final totalHours = totalMinutes ~/ 60;
    final remainingMins = totalMinutes % 60;

    final Map<String, int> byCategory = {};
    final Map<String, int> countByCategory = {};
    for (final e in entries) {
      final cat = e['category'] as String? ?? 'Unknown';
      byCategory[cat] =
          (byCategory[cat] ?? 0) + ((e['durationMinutes'] ?? 0) as int);
      countByCategory[cat] = (countByCategory[cat] ?? 0) + 1;
    }

    final lockedCount = countByCategory['Locked'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox('Sessions', '${entries.length}'),
              const SizedBox(width: 12),
              _statBox(
                'Total Time',
                totalHours > 0
                    ? '${totalHours}h ${remainingMins}m'
                    : '${totalMinutes}m',
              ),
              const SizedBox(width: 12),
              _statBox('Locked Days', '$lockedCount'),
            ],
          ),
          if (byCategory.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Breakdown',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...byCategory.entries.map(
              (entry) => _categoryBar(
                entry.key,
                entry.value,
                totalMinutes,
                count: countByCategory[entry.key] ?? 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryBar(String category, int minutes, int total,
      {int count = 0}) {
    final percent = total == 0 ? 0.0 : minutes / total;
    final catColors = {
      'Locked': AppColors.danger,
      'Usage': AppColors.primary,
      'Focus': AppColors.secondary,
      'Break': AppColors.success,
    };
    final color = catColors[category] ?? AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                  ),
                ],
              ),
              Text(
                '${count}x · ${minutes}m',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, color: AppColors.textMuted, size: 48),
          SizedBox(height: 12),
          Text(
            'No sessions found.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Try clearing filters or use the app more.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildList(List<Map<String, dynamic>> entries) {
    final catColors = {
      'Locked': AppColors.danger,
      'Usage': AppColors.primary,
      'Focus': AppColors.secondary,
      'Break': AppColors.success,
    };

    final catIcons = {
      'Locked': Icons.lock_outline,
      'Usage': Icons.phone_android,
      'Focus': Icons.center_focus_strong_outlined,
      'Break': Icons.coffee_outlined,
    };

    return entries.map((e) {
      final date = (e['date'] as Timestamp?)?.toDate();
      final category = e['category'] as String? ?? 'Unknown';
      final minutes = e['durationMinutes'] as int? ?? 0;
      final note = e['note'] as String?;
      final color = catColors[category] ?? AppColors.primary;
      final icon = catIcons[category] ?? Icons.circle_outlined;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      if (minutes > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${minutes}m',
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy  h:mm a').format(date),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}