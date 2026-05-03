class AppSettings {
  final int dailyLimitMinutes;
  final bool hapticsEnabled;
  final bool strictMode;
  final bool notificationsEnabled;
  final Set<String> excludedPackages; // packages the user has marked as always-allowed

  const AppSettings({
    this.dailyLimitMinutes = 30,
    this.hapticsEnabled = true,
    this.strictMode = false,
    this.notificationsEnabled = true,
    this.excludedPackages = const {},
  });

  /// Packages that are hardcoded and can never be blocked.
  static const Set<String> hardcodedSafePackages = {
    'com.android.phone',
    'com.android.dialer',
    'com.google.android.dialer',
    'com.android.emergency',
    'com.google.android.apps.maps',
    'com.android.mms',
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
  };

  /// All packages that should never be intercepted (hardcoded + user-excluded).
  Set<String> get allExcludedPackages => {
        ...hardcodedSafePackages,
        ...excludedPackages,
      };

  AppSettings copyWith({
    int? dailyLimitMinutes,
    bool? hapticsEnabled,
    bool? strictMode,
    bool? notificationsEnabled,
    Set<String>? excludedPackages,
  }) {
    return AppSettings(
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      strictMode: strictMode ?? this.strictMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      excludedPackages: excludedPackages ?? this.excludedPackages,
    );
  }

  Map<String, dynamic> toMap() => {
        'dailyLimitMinutes': dailyLimitMinutes,
        'hapticsEnabled': hapticsEnabled,
        'strictMode': strictMode,
        'notificationsEnabled': notificationsEnabled,
        'excludedPackages': excludedPackages.toList(),
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        dailyLimitMinutes: (m['dailyLimitMinutes'] as int?) ?? 30,
        hapticsEnabled: (m['hapticsEnabled'] as bool?) ?? true,
        strictMode: (m['strictMode'] as bool?) ?? false,
        notificationsEnabled: (m['notificationsEnabled'] as bool?) ?? true,
        excludedPackages: (m['excludedPackages'] as List?)
                ?.map((e) => e as String)
                .toSet() ??
            const {},
      );
}