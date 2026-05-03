import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/shield_provider.dart';

class ShieldScreen extends StatefulWidget {
  const ShieldScreen({super.key});

  @override
  State<ShieldScreen> createState() => _ShieldScreenState();
}

class _ShieldScreenState extends State<ShieldScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late Timer _clockTimer;
  Duration _msLeft = _timeUntilMidnight();

  static Duration _timeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _msLeft = _timeUntilMidnight());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final shield = context.watch<ShieldProvider>();
    final game = context.watch<GameProvider>();
    final state = game.state;

    final streakColor = state.streak >= 7
        ? AppColors.success
        : state.streak >= 3
            ? AppColors.warning
            : AppColors.textMuted;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock, size: 52, color: AppColors.danger),
                  ),
                ),
                const SizedBox(height: 24),

                Text('Locked.',
                    style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(shield.shieldTarget ?? 'This App',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.danger)),
                const SizedBox(height: 16),

                Text(
                  'You hit your daily limit.\nNo quest. No bypass. No exceptions.\nSee you tomorrow.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text('UNLOCKS IN',
                          style: GoogleFonts.inter(fontSize: 11, letterSpacing: 2, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(_formatCountdown(_msLeft),
                          style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('Resets at midnight',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, size: 16, color: streakColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.lockedToday
                              ? 'Streak reset to 0. Don\'t let it happen again.'
                              : '${state.streak} day streak — protect it tomorrow',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: state.lockedToday ? AppColors.danger : streakColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text('NO MERCY',
                    style: GoogleFonts.inter(fontSize: 12, letterSpacing: 5, color: AppColors.border, fontWeight: FontWeight.w700)),

                if (!shield.settings.strictMode) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: shield.dismissShield,
                    child: Text('dismiss (demo only)',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.border)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}