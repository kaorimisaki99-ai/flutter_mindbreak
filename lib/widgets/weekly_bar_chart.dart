import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_state.dart';
import '../theme/app_theme.dart';

class WeeklyBarChart extends StatelessWidget {
  final List<DayUsage> weeklyUsage;
  final int dailyLimitMinutes;

  const WeeklyBarChart({
    super.key,
    required this.weeklyUsage,
    required this.dailyLimitMinutes,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyUsage.isEmpty) return const SizedBox.shrink();

    final maxMins = weeklyUsage
        .map((d) => d.minutes)
        .fold(dailyLimitMinutes, (a, b) => a > b ? a : b)
        .toDouble();

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    const barMaxHeight = 80.0;
    const labelHeight = 24.0;
    const valueHeight = 16.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Usage',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('Top app · limit ${dailyLimitMinutes}m',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),

          SizedBox(
            height: barMaxHeight + labelHeight + valueHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyUsage.map((day) {
                final isToday = day.date == todayStr;
                final isOver = day.minutes >= dailyLimitMinutes;
                final barH = maxMins > 0
                    ? (day.minutes / maxMins) * barMaxHeight
                    : 0.0;
                final color = isOver
                    ? AppColors.danger
                    : isToday
                        ? AppColors.primary
                        : AppColors.textMuted.withValues(alpha: 0.3);

                // Parse date for day label
                final parts = day.date.split('-');
                String dayLabel = '?';
                if (parts.length == 3) {
                  try {
                    final d = DateTime(
                      int.parse(parts[0]),
                      int.parse(parts[1]),
                      int.parse(parts[2]),
                    );
                    dayLabel = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday - 1];
                  } catch (_) {}
                }

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Usage value above bar
                      SizedBox(
                        height: valueHeight,
                        child: day.minutes > 0
                            ? Text(
                                '${day.minutes}m',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: isOver ? AppColors.danger : AppColors.textMuted,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: barH.clamp(3.0, barMaxHeight),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      // Day label
                      SizedBox(
                        height: labelHeight,
                        child: Center(
                          child: Text(
                            dayLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                              color: isToday ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Limit line legend
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 16,
                height: 1.5,
                color: AppColors.danger.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text('${dailyLimitMinutes}m limit',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}