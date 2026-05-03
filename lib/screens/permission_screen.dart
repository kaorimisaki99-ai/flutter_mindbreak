import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── Channel name must match MainActivity.kt USAGE_CHANNEL exactly ──
const _channel = MethodChannel('com.mindbreak.app/usage_stats');

class PermissionScreen extends StatefulWidget {
  final VoidCallback onAllGranted;
  const PermissionScreen({super.key, required this.onAllGranted});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _usageGranted = false;
  bool _accessibilityGranted = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check every time the user comes back from the Settings screen
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (_checking) return;
    _checking = true;
    try {
      // Method names must match MainActivity.kt exactly
      final usage =
          await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
      final accessibility =
          await _channel.invokeMethod<bool>('hasAccessibilityPermission') ??
              false;
      if (!mounted) return;
      setState(() {
        _usageGranted = usage;
        _accessibilityGranted = accessibility;
      });
      if (usage && accessibility) widget.onAllGranted();
    } on PlatformException catch (e) {
      debugPrint('Permission check error: ${e.message}');
    } catch (e) {
      debugPrint('Permission check unexpected error: $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> _requestUsage() async {
    try {
      await _channel.invokeMethod('requestUsagePermission');
    } on PlatformException catch (e) {
      debugPrint('requestUsagePermission error: ${e.message}');
    }
    // Re-check happens via didChangeAppLifecycleState when user returns
  }

  Future<void> _requestAccessibility() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } on PlatformException catch (e) {
      debugPrint('requestAccessibilityPermission error: ${e.message}');
    }
    // Re-check happens via didChangeAppLifecycleState when user returns
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _usageGranted && _accessibilityGranted;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text('Setup Required',
                  style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'MindBreak needs two permissions to track and block distracting apps.',
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 32),
              _PermissionTile(
                icon: Icons.bar_chart_outlined,
                title: 'Usage Access',
                description: 'Lets MindBreak see how long you use each app.',
                granted: _usageGranted,
                onTap: _usageGranted ? null : _requestUsage,
              ),
              const SizedBox(height: 12),
              _PermissionTile(
                icon: Icons.accessibility_new_outlined,
                title: 'Accessibility Service',
                description:
                    'Lets MindBreak block apps when your limit is reached.',
                granted: _accessibilityGranted,
                onTap: _accessibilityGranted ? null : _requestAccessibility,
              ),
              const Spacer(),
              if (allGranted)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onAllGranted,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Get Started',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Tap each permission above to grant access.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback? onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = granted ? AppColors.success : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: granted
              ? AppColors.success.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: granted
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              granted ? Icons.check_circle : Icons.arrow_forward_ios,
              size: granted ? 22 : 16,
              color: granted ? AppColors.success : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}