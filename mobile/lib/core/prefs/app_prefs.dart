/// App-level preferences (everything that is not pointer/scroll tuning, which lives in TouchpadSettings).
/// Persisted as JSON; loading never throws and every field falls back to its default.
class AppPrefs {
  const AppPrefs({
    this.accentId = 'violet',
    this.haptics = true,
    this.showHints = true,
    this.showQuickBar = true,
    this.orientation = OrientationPref.auto,
    this.onboardingDone = false,
  });

  final String accentId;
  final bool haptics;
  /// Gesture hints on the empty touchpad.
  final bool showHints;
  /// Row of favorite shortcuts on the touchpad screen.
  final bool showQuickBar;
  final OrientationPref orientation;
  final bool onboardingDone;

  AppPrefs copyWith({
    String? accentId, bool? haptics, bool? showHints, bool? showQuickBar, OrientationPref? orientation, bool? onboardingDone,
  }) =>
      AppPrefs(
        accentId: accentId ?? this.accentId,
        haptics: haptics ?? this.haptics,
        showHints: showHints ?? this.showHints,
        showQuickBar: showQuickBar ?? this.showQuickBar,
        orientation: orientation ?? this.orientation,
        onboardingDone: onboardingDone ?? this.onboardingDone,
      );

  Map<String, dynamic> toJson() => {
        'accent': accentId, 'haptics': haptics, 'hints': showHints, 'quick': showQuickBar,
        'orientation': orientation.name, 'onboarded': onboardingDone,
      };

  static AppPrefs fromJson(Object? json) {
    const d = AppPrefs();
    if (json is! Map<String, dynamic>) return d;
    bool b(String k, bool def) => json[k] is bool ? json[k] as bool : def;
    final accent = json['accent'];
    return AppPrefs(
      accentId: accent is String && accent.length <= 20 ? accent : d.accentId,
      haptics: b('haptics', d.haptics),
      showHints: b('hints', d.showHints),
      showQuickBar: b('quick', d.showQuickBar),
      orientation: OrientationPref.values.firstWhere((o) => o.name == json['orientation'], orElse: () => d.orientation),
      onboardingDone: b('onboarded', d.onboardingDone),
    );
  }
}

enum OrientationPref {
  auto('Automatic'),
  portrait('Portrait'),
  landscape('Landscape');

  const OrientationPref(this.label);
  final String label;
}
