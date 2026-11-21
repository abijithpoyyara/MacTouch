/// User-tunable pointer behaviour. Persisted as JSON; every field is clamped on load.
class TouchpadSettings {
  const TouchpadSettings({
    this.sensitivity = 1.2,
    this.accelEnabled = true,
    this.accelStrength = 0.5,
    this.smoothing = 0.2,
    this.scrollSensitivity = 1.5,
    this.naturalScroll = true,
    this.horizontalScroll = true,
    this.invertHorizontal = false,
    this.tapToClick = true,
    this.twoFingerRightClick = true,
    this.deadzone = 3.0,
  });

  /// Cursor distance per finger distance (0.3 - 3.0).
  final double sensitivity;
  final bool accelEnabled;
  /// 0 = none, 1 = up to 4x faster at high finger speed.
  final double accelStrength;
  /// 0 = raw, 0.8 = heavy smoothing.
  final double smoothing;
  /// Scroll pixels per finger pixel (0.3 - 4.0).
  final double scrollSensitivity;
  /// Content follows the fingers (macOS default). Off = traditional wheel direction.
  final bool naturalScroll;
  final bool horizontalScroll;
  final bool invertHorizontal;
  final bool tapToClick;
  final bool twoFingerRightClick;
  /// Touch sensitivity: how far a finger must move (in px) before the cursor starts. Lower = more sensitive (0 - 8).
  final double deadzone;

  static const sensitivityRange = (min: 0.3, max: 3.0);
  static const smoothingRange = (min: 0.0, max: 0.8);
  static const scrollRange = (min: 0.3, max: 4.0);
  static const deadzoneRange = (min: 0.0, max: 8.0);

  TouchpadSettings copyWith({
    double? sensitivity, bool? accelEnabled, double? accelStrength, double? smoothing,
    double? scrollSensitivity, bool? naturalScroll, bool? horizontalScroll, bool? invertHorizontal,
    bool? tapToClick, bool? twoFingerRightClick, double? deadzone,
  }) =>
      TouchpadSettings(
        sensitivity: sensitivity ?? this.sensitivity,
        accelEnabled: accelEnabled ?? this.accelEnabled,
        accelStrength: accelStrength ?? this.accelStrength,
        smoothing: smoothing ?? this.smoothing,
        scrollSensitivity: scrollSensitivity ?? this.scrollSensitivity,
        naturalScroll: naturalScroll ?? this.naturalScroll,
        horizontalScroll: horizontalScroll ?? this.horizontalScroll,
        invertHorizontal: invertHorizontal ?? this.invertHorizontal,
        tapToClick: tapToClick ?? this.tapToClick,
        twoFingerRightClick: twoFingerRightClick ?? this.twoFingerRightClick,
        deadzone: deadzone ?? this.deadzone,
      );

  Map<String, dynamic> toJson() => {
        'sensitivity': sensitivity, 'accelEnabled': accelEnabled, 'accelStrength': accelStrength,
        'smoothing': smoothing, 'scrollSensitivity': scrollSensitivity, 'naturalScroll': naturalScroll,
        'horizontalScroll': horizontalScroll, 'invertHorizontal': invertHorizontal,
        'tapToClick': tapToClick, 'twoFingerRightClick': twoFingerRightClick, 'deadzone': deadzone,
      };

  /// Never throws: unknown, missing or out-of-range values fall back to defaults / get clamped.
  static TouchpadSettings fromJson(Object? json) {
    const d = TouchpadSettings();
    if (json is! Map<String, dynamic>) return d;
    double num_(String k, double def, double lo, double hi) {
      final v = json[k];
      return v is num && v.isFinite ? v.toDouble().clamp(lo, hi).toDouble() : def;
    }

    bool bool_(String k, bool def) => json[k] is bool ? json[k] as bool : def;
    return TouchpadSettings(
      sensitivity: num_('sensitivity', d.sensitivity, sensitivityRange.min, sensitivityRange.max),
      accelEnabled: bool_('accelEnabled', d.accelEnabled),
      accelStrength: num_('accelStrength', d.accelStrength, 0, 1),
      smoothing: num_('smoothing', d.smoothing, smoothingRange.min, smoothingRange.max),
      scrollSensitivity: num_('scrollSensitivity', d.scrollSensitivity, scrollRange.min, scrollRange.max),
      naturalScroll: bool_('naturalScroll', d.naturalScroll),
      horizontalScroll: bool_('horizontalScroll', d.horizontalScroll),
      invertHorizontal: bool_('invertHorizontal', d.invertHorizontal),
      tapToClick: bool_('tapToClick', d.tapToClick),
      twoFingerRightClick: bool_('twoFingerRightClick', d.twoFingerRightClick),
      deadzone: num_('deadzone', d.deadzone, deadzoneRange.min, deadzoneRange.max),
    );
  }
}
