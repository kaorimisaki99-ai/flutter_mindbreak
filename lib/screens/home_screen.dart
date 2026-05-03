import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/shield_provider.dart';
import '../widgets/weekly_bar_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Poll every 60 seconds while the app is open
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  // Refresh usage whenever user comes back from another app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final shield = context.read<ShieldProvider>();
    final game = context.read<GameProvider>();
    await shield.refresh();
    final top = shield.topAppSorted;
    if (top != null) game.updateTodayUsage(top.usedMinutesToday);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final shield = context.watch<ShieldProvider>();

    // Show a loading indicator while we enumerate installed apps
    if (shield.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final topApp = shield.topAppSorted;
    final limit = shield.settings.dailyLimitMinutes;
    final isOver = topApp != null && topApp.usedMinutesToday >= limit;
    final usagePct = topApp != null
        ? (topApp.usedMinutesToday / limit).clamp(0.0, 1.0)
        : 0.0;
    final remaining = topApp != null ? (limit - topApp.usedMinutesToday).clamp(0, limit) : 0;

    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    final resetStr = '${diff.inHours}h ${diff.inMinutes % 60}m';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            // Header
            Text('MindBreak',
                style: GoogleFonts.inter(
                    fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(today,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
            const SizedBox(height: 18),

            // Weekly Bar Chart
            WeeklyBarChart(
              weeklyUsage: game.weeklyUsage,
              dailyLimitMinutes: limit,
            ),
            const SizedBox(height: 14),

            // Top App Widget
            if (topApp != null)
              _TopAppWidget(
                appName: topApp.name,
                iconData: _iconFor(topApp.iconAsset),
                usedMinutes: topApp.usedMinutesToday,
                limitMinutes: limit,
                usagePct: usagePct,
                remaining: remaining,
                isOver: isOver,
                lockedToday: game.state.lockedToday,
                resetStr: resetStr,
                onLock: () {
                  game.markLockedToday();
                  game.updateTodayUsage(topApp.usedMinutesToday);
                  shield.triggerLock(topApp.name);
                },
                onViewLock: () => shield.triggerLock(topApp.name),
              ),
            const SizedBox(height: 14),

            // All apps ranked list
            Text('ALL APPS TODAY',
                style: GoogleFonts.inter(
                    fontSize: 10, letterSpacing: 1.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...shield.sortedApps.asMap().entries.map((entry) {
              final i = entry.key;
              final app = entry.value;
              final pct = (app.usedMinutesToday / limit).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text('${i + 1}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Icon(_iconFor(app.iconAsset),
                          size: 17, color: i == 0 ? AppColors.primary : AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.name,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: i == 0 ? AppColors.textPrimary : AppColors.textMuted,
                                    fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: AppColors.muted,
                                valueColor: AlwaysStoppedAnimation(
                                    i == 0 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.5)),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${app.usedMinutesToday}m',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: i == 0 ? AppColors.textPrimary : AppColors.textMuted,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 14),
            // Simulate section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIMULATE USAGE',
                      style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: shield.sortedApps.map((app) {
                      return GestureDetector(
                        onTap: () => shield.simulateUsage(app.id, 5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconFor(app.iconAsset), size: 11, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text('${app.name.split(' ').first} +5m',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String asset) {
    switch (asset) {
      case 'photo_camera':   return Icons.photo_camera_outlined;
      case 'camera_alt':     return Icons.camera_alt_outlined;
      case 'music_note':     return Icons.music_note_outlined;
      case 'headphones':     return Icons.headphones_outlined;
      case 'tag':            return Icons.tag;
      case 'play_circle':    return Icons.play_circle_outline;
      case 'movie':          return Icons.movie_outlined;
      case 'thumb_up':       return Icons.thumb_up_outlined;
      case 'chat':           return Icons.chat_outlined;
      case 'send':           return Icons.send_outlined;
      case 'forum':          return Icons.forum_outlined;
      case 'language':       return Icons.language;
      case 'email':          return Icons.email_outlined;
      case 'map':            return Icons.map_outlined;
      case 'alarm':          return Icons.alarm;
      case 'calculate':      return Icons.calculate_outlined;
      case 'event':          return Icons.event_outlined;
      case 'settings':       return Icons.settings_outlined;
      case 'phone':          return Icons.phone_outlined;
      case 'sms':            return Icons.sms_outlined;
      case 'photo_library':  return Icons.photo_library_outlined;
      case 'sports_esports': return Icons.sports_esports_outlined;
      case 'shopping_cart':  return Icons.shopping_cart_outlined;
      case 'newspaper':      return Icons.newspaper_outlined;
      case 'account_balance_wallet': return Icons.account_balance_wallet_outlined;
      default:               return Icons.smartphone_outlined;
    }
  }
}

class _TopAppWidget extends StatelessWidget {
  final String appName;
  final IconData iconData;
  final int usedMinutes;
  final int limitMinutes;
  final double usagePct;
  final int remaining;
  final bool isOver;
  final bool lockedToday;
  final String resetStr;
  final VoidCallback onLock;
  final VoidCallback onViewLock;

  const _TopAppWidget({
    required this.appName,
    required this.iconData,
    required this.usedMinutes,
    required this.limitMinutes,
    required this.usagePct,
    required this.remaining,
    required this.isOver,
    required this.lockedToday,
    required this.resetStr,
    required this.onLock,
    required this.onViewLock,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = isOver
        ? AppColors.danger
        : usagePct > 0.75
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOver ? AppColors.danger : AppColors.border,
          width: isOver ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isOver ? AppColors.danger.withValues(alpha: 0.15) : AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, color: isOver ? AppColors.danger : AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appName,
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Most used today',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOver ? AppColors.danger : AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isOver ? Icons.lock : Icons.lock_open,
                        size: 11, color: isOver ? Colors.white : AppColors.success),
                    const SizedBox(width: 4),
                    Text(isOver ? 'LOCKED' : 'FREE',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOver ? Colors.white : AppColors.success)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${usedMinutes}m',
                  style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isOver ? AppColors.danger : AppColors.textPrimary)),
              const SizedBox(width: 6),
              Text('of', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(width: 6),
              Text('${limitMinutes}m', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              if (!isOver) ...[
                const SizedBox(width: 6),
                Text('· ${remaining}m left',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usagePct,
              backgroundColor: AppColors.muted,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 8,
            ),
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Text('Resets in $resetStr',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
          if (isOver && !lockedToday) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLock,
                icon: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                label: Text('Limit Reached — Lock Now',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          if (isOver && lockedToday) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewLock,
                icon: const Icon(Icons.lock, size: 15),
                label: Text('View Lock Screen',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.muted,
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}