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

    // Max value is at least the daily limit so the dashed line always fits
    final maxMins = weeklyUsage
        .map((d) => d.minutes)
        .fold(dailyLimitMinutes, (a, b) => a > b ? a : b)
        .toDouble();

    const barMaxHeight = 72.0;
    const labelHeight = 20.0;
    const valueLabelHeight = 14.0;
    const totalHeight = barMaxHeight + labelHeight + valueLabelHeight + 4;

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    // Where the dashed limit line sits, measured from the TOP of the bar area
    final limitLineTop = barMaxHeight - (dailyLimitMinutes / maxMins) * barMaxHeight;

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
          const SizedBox(height: 14),

          SizedBox(
            height: totalHeight,
            child: Stack(
              children: [
                // ── Dashed limit line overlaid on bar area ──────────────────
                Positioned(
                  // offset from top: valueLabelHeight + 4 (gap) + limitLineTop
                  top: valueLabelHeight + 4 + limitLineTop,
                  left: 0,
                  right: 0,
                  child: const _DashedLine(),
                ),

                // ── Bars + labels in a single aligned Row ───────────────────
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: weeklyUsage.map((day) {
                      final isToday = day.date == todayStr;
                      final isOver = day.minutes >= dailyLimitMinutes;

                      // bar height proportional to maxMins, min 3 so it's visible
                      final barH = maxMins > 0
                          ? ((day.minutes / maxMins) * barMaxHeight).clamp(3.0, barMaxHeight)
                          : 3.0;

                      final color = isOver
                          ? AppColors.danger
                          : isToday
                              ? AppColors.primary
                              : AppColors.textMuted.withValues(alpha: 0.3);

                      final parts = day.date.split('-');
                      final dayLabel = parts.length == 3
                          ? _weekdayLabel(DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                              int.parse(parts[2])).weekday)
                          : '?';

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // minute value above bar (fixed height so bars bottom-align)
                            SizedBox(
                              height: valueLabelHeight,
                              child: day.minutes > 0
                                  ? Text(
                                      '${day.minutes}m',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        color: isOver
                                            ? AppColors.danger
                                            : AppColors.textMuted,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 4),
                            // bar
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: barH,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            // day label (always same height → bars stay aligned)
                            SizedBox(
                              height: labelHeight,
                              child: Center(
                                child: Text(
                                  dayLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isToday
                                        ? AppColors.primary
                                        : AppColors.textMuted,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.danger.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}