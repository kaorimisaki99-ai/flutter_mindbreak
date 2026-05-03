import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../providers/shield_provider.dart';
import '../models/tracked_app.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _deviceId = 'loading...';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            Text('Settings',
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // ── Daily Limit ──────────────────────────────────────────────
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
                    color: active ? color.withValues(alpha: 0.12) : AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: active ? color : AppColors.border, width: active ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: active ? color.withValues(alpha: 0.2) : AppColors.muted,
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
                                style: GoogleFonts.inter(
                                    fontSize: 18, fontWeight: FontWeight.w700,
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
                          child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black)),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // ── Behaviour ────────────────────────────────────────────────
            _SectionTitle('Behavior'),
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  _ToggleRow(
                    icon: Icons.bolt,
                    label: 'Strict Mode',
                    sublabel: 'Hides dismiss on lock screen — truly no way out',
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

            const SizedBox(height: 14),

            // ── Excluded Apps ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionTitle('Excluded Apps'),
                TextButton.icon(
                  onPressed: () => _openExcludePicker(context, shield),
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: Text('Manage', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('These apps will never be blocked by MindBreak.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 10),

                  // Hardcoded safety apps badge
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      // Hardcoded ones
                      ..._hardcodedSafeLabels.map((name) => _AppChip(
                            label: name,
                            isHardcoded: true,
                            onRemove: null,
                          )),
                      // User-excluded apps
                      ...settings.excludedPackages.map((pkg) {
                        final app = shield.allApps.firstWhere(
                          (a) => a.packageId == pkg,
                          orElse: () => TrackedApp(id: pkg, name: pkg.split('.').last, packageId: pkg, iconAsset: 'smartphone'),
                        );
                        return _AppChip(
                          label: app.name,
                          isHardcoded: false,
                          onRemove: () => shield.toggleExcluded(pkg),
                        );
                      }),

                      if (settings.excludedPackages.isEmpty)
                        Text('No user-excluded apps yet. Tap Manage to add.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Account ──────────────────────────────────────────────────
            _SectionTitle('Account'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.smartphone, color: AppColors.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('One Device · One Account',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
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
                        Text('DEVICE ID', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(_deviceId, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
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

  static const _hardcodedSafeLabels = ['Phone', 'Emergency SOS', 'Maps', 'Messages', 'MindBreak'];

  void _openExcludePicker(BuildContext context, ShieldProvider shield) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExcludePickerSheet(shield: shield),
    );
  }
}

// ── Exclude Picker Bottom Sheet ──────────────────────────────────────────────

class _ExcludePickerSheet extends StatefulWidget {
  final ShieldProvider shield;
  const _ExcludePickerSheet({required this.shield});

  @override
  State<_ExcludePickerSheet> createState() => _ExcludePickerSheetState();
}

class _ExcludePickerSheetState extends State<_ExcludePickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final shield = context.watch<ShieldProvider>();
    final allApps = shield.allApps
      ..sort((a, b) => a.name.compareTo(b.name));

    final filtered = _search.isEmpty
        ? allApps
        : allApps
            .where((a) => a.name.toLowerCase().contains(_search.toLowerCase()) ||
                a.packageId.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exclude Apps',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Selected apps will never be blocked.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 12),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search apps…',
                        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No apps found',
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final app = filtered[i];
                        final isExcluded = shield.isExcluded(app.packageId);
                        final isHardcoded = AppSettings.hardcodedSafePackages.contains(app.packageId);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isExcluded ? AppColors.success.withValues(alpha: 0.15) : AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isExcluded ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              _iconFor(app.iconAsset),
                              size: 18,
                              color: isExcluded ? AppColors.success : AppColors.textMuted,
                            ),
                          ),
                          title: Text(app.name,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                          subtitle: Text(app.packageId,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis),
                          trailing: isHardcoded
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('ALWAYS SAFE',
                                      style: GoogleFonts.inter(
                                          fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.success)),
                                )
                              : Checkbox(
                                  value: isExcluded,
                                  activeColor: AppColors.success,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (_) => shield.toggleExcluded(app.packageId),
                                ),
                          onTap: isHardcoded ? null : () => shield.toggleExcluded(app.packageId),
                        );
                      },
                    ),
            ),
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

// ── Small widgets ────────────────────────────────────────────────────────────

class _AppChip extends StatelessWidget {
  final String label;
  final bool isHardcoded;
  final VoidCallback? onRemove;

  const _AppChip({required this.label, required this.isHardcoded, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(left: 10, top: 6, bottom: 6, right: isHardcoded ? 10 : 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isHardcoded ? Icons.lock_outline : Icons.check,
              size: 10, color: AppColors.success),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
          if (!isHardcoded && onRemove != null) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 14, color: AppColors.success),
            ),
          ],
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                    Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(sublabel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: AppColors.border, indent: 14, endIndent: 14),
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
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary), overflow: TextOverflow.ellipsis),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      );
}