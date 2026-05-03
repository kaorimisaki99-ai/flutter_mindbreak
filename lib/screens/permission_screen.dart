import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/shield_provider.dart';
import 'package:flutter/services.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onAllGranted;
  const PermissionScreen({super.key, required this.onAllGranted});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.mindbreak.app/usage_stats');

  bool _hasUsage = false;
  bool _hasAccessibility = false;
  bool _loading = true;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _loading = true);
    try {
      final usage =
          await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
      final accessibility =
          await _channel.invokeMethod<bool>('hasAccessibilityPermission') ??
              false;
      if (!mounted) return;
      setState(() {
        _hasUsage = usage;
        _hasAccessibility = accessibility;
        _loading = false;
      });
      if (usage && accessibility) {
        await context.read<ShieldProvider>().refresh();
        if (mounted) widget.onAllGranted();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestUsage() async {
    await _channel.invokeMethod('requestUsagePermission');
  }

  Future<void> _requestAccessibility() async {
    await _channel.invokeMethod('requestAccessibilityPermission');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Setup MindBreak',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Grant the following permissions to enable app tracking and blocking.',
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Permission 1
              _PermissionTile(
                icon: Icons.bar_chart_outlined,
                title: 'Usage Access',
                description:
                    'Lets MindBreak see how long you use each app per day.',
                isGranted: _hasUsage,
                onTap: _hasUsage ? null : _requestUsage,
              ),
              const SizedBox(height: 12),

              // Permission 2
              _PermissionTile(
                icon: Icons.accessibility_new_outlined,
                title: 'Accessibility Service',
                description:
                    'Allows MindBreak to detect and block apps when your limit is reached.',
                isGranted: _hasAccessibility,
                onTap: _hasAccessibility ? null : _requestAccessibility,
              ),

              const SizedBox(height: 32),

              // Check Again button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _checkPermissions,
                  icon: const Icon(Icons.refresh,
                      size: 18, color: AppColors.textMuted),
                  label: Text(
                    'Check Again',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textMuted),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_hasUsage && _hasAccessibility)
                      ? widget.onAllGranted
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.muted,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    (_hasUsage && _hasAccessibility)
                        ? 'Continue →'
                        : 'Grant Permissions Above',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: (_hasUsage && _hasAccessibility)
                          ? AppColors.primaryFg
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  'Your data stays on your device. Nothing is shared.',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
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
  final bool isGranted;
  final VoidCallback? onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? AppColors.success.withOpacity(0.4)
              : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGranted
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_outline : icon,
              color: isGranted ? AppColors.success : AppColors.textMuted,
              size: 22,
            ),
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
                const SizedBox(height: 3),
                Text(description,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isGranted)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Granted',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success)),
            )
          else
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text('Enable',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }
}