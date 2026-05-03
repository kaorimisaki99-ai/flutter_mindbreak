class TrackedApp {
  final String id;
  final String name;
  final String packageId;
  final String iconAsset;
  int usedMinutesToday;

  TrackedApp({
    required this.id,
    required this.name,
    required this.packageId,
    required this.iconAsset,
    this.usedMinutesToday = 0,
  });

  TrackedApp copyWith({int? usedMinutesToday}) => TrackedApp(
        id: id,
        name: name,
        packageId: packageId,
        iconAsset: iconAsset,
        usedMinutesToday: usedMinutesToday ?? this.usedMinutesToday,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'packageId': packageId,
        'iconAsset': iconAsset,
        'usedMinutesToday': usedMinutesToday,
      };

  factory TrackedApp.fromMap(Map<String, dynamic> m) => TrackedApp(
        id: m['id'] as String,
        name: m['name'] as String,
        packageId: m['packageId'] as String,
        iconAsset: (m['iconAsset'] as String?) ?? 'smartphone',
        usedMinutesToday: (m['usedMinutesToday'] as int?) ?? 0,
      );

  /// Creates a TrackedApp from a device installed app map
  factory TrackedApp.fromInstalledApp(Map<String, String> app) => TrackedApp(
        id: app['packageId']!,
        name: app['name']!,
        packageId: app['packageId']!,
        iconAsset: 'smartphone',
        usedMinutesToday: 0,
      );

  // Fallback defaults if installed apps can't be fetched
  static List<TrackedApp> get defaults => [
        TrackedApp(id: '1', name: 'Instagram', packageId: 'com.instagram.android', iconAsset: 'photo_camera'),
        TrackedApp(id: '2', name: 'TikTok', packageId: 'com.zhiliaoapp.musically', iconAsset: 'music_note'),
        TrackedApp(id: '3', name: 'Twitter / X', packageId: 'com.twitter.android', iconAsset: 'tag'),
        TrackedApp(id: '4', name: 'YouTube', packageId: 'com.google.android.youtube', iconAsset: 'play_circle'),
      ];
}