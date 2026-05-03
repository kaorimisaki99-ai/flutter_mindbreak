// Default excluded packages — these are never time-limited
const List<String> kDefaultExcludedPackages = [
  // Phone & Communication
  'com.android.phone',
  'com.android.dialer',
  'com.samsung.android.dialer',
  'com.google.android.dialer',
  'com.android.contacts',
  'com.samsung.android.contacts',
  'com.google.android.contacts',
  'com.android.mms',
  'com.samsung.android.messaging',
  'com.google.android.apps.messaging',
  'com.android.messaging',
  // Settings
  'com.android.settings',
  'com.samsung.android.settings',
  'com.miui.settings',
  // Music / Media
  'com.google.android.music',
  'com.samsung.android.music',
  'com.spotify.music',
  'com.android.music',
  // Calculator
  'com.android.calculator2',
  'com.samsung.android.calculator',
  'com.google.android.calculator',
  // Calendar
  'com.android.calendar',
  'com.samsung.android.calendar',
  'com.google.android.calendar',
  // Files
  'com.android.documentsui',
  'com.samsung.android.myfiles',
  'com.google.android.documentsui',
  'com.miui.filemanager',
  // Photos / Gallery
  'com.google.android.apps.photos',
  'com.samsung.android.gallery3d',
  'com.android.gallery3d',
  'com.miui.gallery',
  // Clock
  'com.android.deskclock',
  'com.samsung.android.deskclock',
  'com.google.android.deskclock',
  // Notes
  'com.samsung.android.note',
  'com.google.android.keep',
  'com.miui.notes',
  // Compass
  'com.samsung.android.compass',
  'com.miui.compass',
  // MindBreak itself
  'com.mindbreak.app',
  // Google
  'com.google.android.googlequicksearchbox',
  'com.google.android.gms',
  // Recorder
  'com.samsung.android.voicenote',
  'com.android.soundrecorder',
  'com.google.android.apps.recorder',
  // Radio
  'com.sec.android.app.fm',
  'com.android.fmradio',
  // App Store / Market
  'com.android.vending',
  'com.samsung.android.app.galaxyapps',
  'com.huawei.appmarket',
  'com.miui.applicationstore',
  // Maps
  'com.google.android.apps.maps',
  'com.samsung.android.maps',
  // Camera
  'com.android.camera',
  'com.android.camera2',
  'com.samsung.android.camera',
  'com.google.android.GoogleCamera',
  'com.miui.camera',
];

class AppSettings {
  final int dailyLimitMinutes;
  final bool hapticsEnabled;
  final bool strictMode;
  final bool notificationsEnabled;
  final List<String> excludedPackages;

  AppSettings({
    this.dailyLimitMinutes = 30,
    this.hapticsEnabled = true,
    this.strictMode = false,
    this.notificationsEnabled = true,
    List<String>? excludedPackages,
  }) : excludedPackages = excludedPackages ?? List.from(kDefaultExcludedPackages);

  bool isExcluded(String packageId) => excludedPackages.contains(packageId);

  AppSettings copyWith({
    int? dailyLimitMinutes,
    bool? hapticsEnabled,
    bool? strictMode,
    bool? notificationsEnabled,
    List<String>? excludedPackages,
  }) {
    return AppSettings(
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      strictMode: strictMode ?? this.strictMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      excludedPackages: excludedPackages ?? List.from(this.excludedPackages),
    );
  }

  AppSettings withToggleExclusion(String packageId) {
    final updated = List<String>.from(excludedPackages);
    if (updated.contains(packageId)) {
      updated.remove(packageId);
    } else {
      updated.add(packageId);
    }
    return copyWith(excludedPackages: updated);
  }

  Map<String, dynamic> toMap() => {
        'dailyLimitMinutes': dailyLimitMinutes,
        'hapticsEnabled': hapticsEnabled,
        'strictMode': strictMode,
        'notificationsEnabled': notificationsEnabled,
        'excludedPackages': excludedPackages,
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        dailyLimitMinutes: (m['dailyLimitMinutes'] as int?) ?? 30,
        hapticsEnabled: (m['hapticsEnabled'] as bool?) ?? true,
        strictMode: (m['strictMode'] as bool?) ?? false,
        notificationsEnabled: (m['notificationsEnabled'] as bool?) ?? true,
        excludedPackages: m['excludedPackages'] != null
            ? List<String>.from(m['excludedPackages'] as List)
            : List.from(kDefaultExcludedPackages),
      );
}