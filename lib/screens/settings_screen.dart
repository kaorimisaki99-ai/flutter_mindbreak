import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/app_settings.dart';
import '../providers/game_provider.dart';
import '../providers/shield_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _deviceId = 'loading...';
  String _appSearch = '';

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final info = DeviceInfoPlugin();
    try {
      final android = await info.androidInfo;
      setState(() => _deviceId = android.id);
    } catch (_) {
      setState(() => _deviceId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown');
    }
  }

  static const _limitPresets = [
    {'label': 'Strict', 'minutes': 15, 'desc': '15 minutes · maximum discipline', 'icon': Icons.bolt, 'color': AppColors.danger},
    {'label': 'Moderate', 'minutes': 30, 'desc': '30 minutes · balanced control', 'icon': Icons.track_changes, 'color': AppColors.warning},
    {'label': 'Relaxed', 'minutes': 60, 'desc': '60 minutes · light awareness', 'icon': Icons.air, 'color': AppColors.primary},
  ];

  @override
  Widget build(BuildContext context) {
    final shield = context.watch<ShieldProvider>();
    final game = context.watch<GameProvider>();
    final settings = shield.settings;

    // All installed apps sorted alphabetically
    final allApps = [...shield.trackedApps]..sort((a, b) => a.name.compareTo(b.name));

    // Filter by search
    final filteredApps = _appSearch.isEmpty
        ? allApps
        : allApps.where((a) => a.name.toLowerCase().contains(_appSearch.toLowerCase())).toList();

    // Split into excluded (checked) and included (unchecked)
    final excludedApps = filteredApps.where((a) => settings.isExcluded(a.packageId)).toList();
    final includedApps = filteredApps.where((a) => !settings.isExcluded(a.packageId)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            Text('Settings',
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // ── Daily Limit ──────────────────────────────────────
            _SectionTitle('Daily Time Limit'),
            ..._limitPresets.map((preset) {
              final active = settings.dailyLimitMinutes == (preset['minutes'] as int);
              final color = preset['color'] as Color;
              return GestureDetector(
                onTap: () => shield.updateSettings(settings.copyWith(dailyLimitMinutes: preset['minutes'] as int)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(0.10) : AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: active ? color : AppColors.border, width: active ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: active ? color.withOpacity(0.2) : AppColors.muted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(preset['icon'] as IconData, color: active ? color : AppColors.textMuted, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(preset['label'] as String,
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700,
                                    color: active ? color : AppColors.textPrimary)),
                            Text(preset['desc'] as String,
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      if (active)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                          child: Text('ACTIVE',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              );
            }),

            // ── App Time Limit List ───────────────────────────────
            const SizedBox(height: 8),
            _SectionTitle('App Time Limits'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Checked apps are EXCLUDED from time limits. Uncheck an app to start tracking it.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search box
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _appSearch = v),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                _StatChip(
                  label: '${includedApps.length} tracked',
                  color: AppColors.danger,
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: '${excludedApps.length} excluded',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // App list
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: allApps.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No apps found.\nGrant permissions and restart.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                      ),
                    )
                  : filteredApps.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No apps match "$_appSearch"',
                                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                          ),
                        )
                      : Column(
                          children: [
                            // Excluded apps (checked) first
                            if (excludedApps.isNotEmpty) ...[
                              _AppListHeader(
                                label: 'EXCLUDED FROM LIMITS (${excludedApps.length})',
                                color: AppColors.success,
                              ),
                              ...excludedApps.asMap().entries.map((entry) {
                                final isLast = entry.key == excludedApps.length - 1 && includedApps.isEmpty;
                                return _AppTile(
                                  app: entry.value,
                                  isExcluded: true,
                                  showDivider: !isLast,
                                  onToggle: () => shield.toggleExclusion(entry.value.packageId),
                                );
                              }),
                            ],

                            // Included apps (unchecked) — subject to time limit
                            if (includedApps.isNotEmpty) ...[
                              _AppListHeader(
                                label: 'TIME LIMITED (${includedApps.length})',
                                color: AppColors.danger,
                              ),
                              ...includedApps.asMap().entries.map((entry) {
                                final isLast = entry.key == includedApps.length - 1;
                                return _AppTile(
                                  app: entry.value,
                                  isExcluded: false,
                                  showDivider: !isLast,
                                  onToggle: () => shield.toggleExclusion(entry.value.packageId),
                                );
                              }),
                            ],
                          ],
                        ),
            ),

            // ── Behavior ──────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionTitle('Behavior'),
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  _ToggleRow(
                    icon: Icons.bolt,
                    label: 'Strict Mode',
                    sublabel: 'Hides dismiss on lock screen',
                    value: settings.strictMode,
                    onChanged: (v) => shield.updateSettings(settings.copyWith(strictMode: v)),
                  ),
                  _ToggleRow(
                    icon: Icons.notifications_outlined,
                    label: 'Focus Notifications',
                    sublabel: 'Daily reminders before your limit is reached',
                    value: settings.notificationsEnabled,
                    onChanged: (v) => shield.updateSettings(settings.copyWith(notificationsEnabled: v)),
                  ),
                  _ToggleRow(
                    icon: Icons.vibration,
                    label: 'Haptic Feedback',
                    sublabel: 'Vibrations on key interactions',
                    value: settings.hapticsEnabled,
                    onChanged: (v) => shield.updateSettings(settings.copyWith(hapticsEnabled: v)),
                    showDivider: false,
                  ),
                ],
              ),
            ),

            // ── Account ───────────────────────────────────────────
            const SizedBox(height: 14),
            _SectionTitle('Account'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.smartphone, color: AppColors.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('One Device · One Account',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text('No sign-in. No cloud sync. No cheating.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEVICE ID',
                            style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.5,
                                color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(_deviceId,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _AccountStat(value: '${game.state.streak}', label: 'streak'),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _AccountStat(value: '${game.state.points}', label: 'points'),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _AccountStat(value: game.rankInfo.title, label: 'rank'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('MindBreak · v1.0.0 · No mercy, no excuses',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _AppListHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _AppListHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class _AppTile extends StatelessWidget {
  final dynamic app;
  final bool isExcluded;
  final bool showDivider;
  final VoidCallback onToggle;

  const _AppTile({
    required this.app,
    required this.isExcluded,
    required this.showDivider,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isExcluded
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.smartphone_outlined,
              size: 18,
              color: isExcluded ? AppColors.success : AppColors.danger,
            ),
          ),
          title: Text(
            app.name,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            app.packageId,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Transform.scale(
            scale: 0.85,
            child: Checkbox(
              value: isExcluded,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.success,
              checkColor: Colors.white,
              side: BorderSide(
                color: isExcluded ? AppColors.success : AppColors.textMuted,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          onTap: onToggle,
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.border, indent: 14, endIndent: 14),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text(sublabel,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.border, indent: 14, endIndent: 14),
      ],
    );
  }
}

class _AccountStat extends StatelessWidget {
  final String value;
  final String label;
  const _AccountStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.primary),
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      );
}